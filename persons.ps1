#####################################################
# HelloID-Conn-Prov-Source-AFAS-Profit-Persons
#
# Version: 2.0.0.2
#####################################################

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$c = $configuration | ConvertFrom-Json

$baseUri = $c.BaseUrl
$token = $c.Token
$positionsAction = $c.positionsAction

# Set debug logging
switch ($($c.isDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

Write-Information "Start person import: Base URL: $baseUri, Using positionsAction: $positionsAction, token length: $($token.length)"

#region functions
function Resolve-HTTPError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            FullyQualifiedErrorId = $ErrorObject.FullyQualifiedErrorId
            MyCommand             = $ErrorObject.InvocationInfo.MyCommand
            RequestUri            = $ErrorObject.TargetObject.RequestUri
            ScriptStackTrace      = $ErrorObject.ScriptStackTrace
            ErrorMessage          = ''
        }
        if ($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') {
            $httpErrorObj.ErrorMessage = $ErrorObject.ErrorDetails.Message
        }
        elseif ($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException') {
            $httpErrorObj.ErrorMessage = [System.IO.StreamReader]::new($ErrorObject.Exception.Response.GetResponseStream()).ReadToEnd()
        }
        Write-Output $httpErrorObj
    }
}

function Get-ErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,
            ValueFromPipeline
        )]
        [object]$ErrorObject
    )
    process {
        $errorMessage = [PSCustomObject]@{
            VerboseErrorMessage = $null
            AuditErrorMessage   = $null
        }

        if ( $($ErrorObject.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or $($ErrorObject.Exception.GetType().FullName -eq 'System.Net.WebException')) {
            $httpErrorObject = Resolve-HTTPError -Error $ErrorObject

            $errorMessage.VerboseErrorMessage = $httpErrorObject.ErrorMessage

            $errorMessage.AuditErrorMessage = $httpErrorObject.ErrorMessage
        }

        # If error message empty, fall back on $ex.Exception.Message
        if ([String]::IsNullOrEmpty($errorMessage.VerboseErrorMessage)) {
            $errorMessage.VerboseErrorMessage = $ErrorObject.Exception.Message
        }
        if ([String]::IsNullOrEmpty($errorMessage.AuditErrorMessage)) {
            $errorMessage.AuditErrorMessage = $ErrorObject.Exception.Message
        }

        Write-Output $errorMessage
    }
}

function Get-AFASConnectorData {
    param(
        [parameter(Mandatory = $true)]$Token,
        [parameter(Mandatory = $true)]$BaseUri,
        [parameter(Mandatory = $true)]$Connector,
        [parameter(Mandatory = $true)]$OrderByFieldIds,
        [parameter(Mandatory = $true)][ref]$data
    )

    try {
        Write-Verbose "Starting downloading objects through get-connector [$connector]"
        $encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Token))
        $authValue = "AfasToken $encodedToken"
        $Headers = @{ Authorization = $authValue }
        $Headers.Add("IntegrationId", "45963_140664") # Fixed value - Tools4ever Partner Integration ID

        $take = 1000
        $skip = 0

        $uri = $BaseUri + "/connectors/" + $Connector + "?skip=$skip&take=$take&orderbyfieldids=$OrderByFieldIds"
        $dataset = Invoke-RestMethod -Method Get -Uri $uri -Headers $Headers -UseBasicParsing

        foreach ($record in $dataset.rows) { [void]$data.Value.add($record) }

        $skip += $take
        while (@($dataset.rows).count -eq $take) {
            $uri = $BaseUri + "/connectors/" + $Connector + "?skip=$skip&take=$take&orderbyfieldids=$OrderByFieldIds"

            $dataset = Invoke-RestMethod -Method Get -Uri $uri -Headers $Headers -UseBasicParsing

            $skip += $take

            foreach ($record in $dataset.rows) { [void]$data.Value.add($record) }
        }
        Write-Verbose "Downloaded [$($data.Value.count)] records through get-connector [$connector]"
    }
    catch {
        $data.Value = $null

        $ex = $PSItem
        $errorMessage = Get-ErrorMessage -ErrorObject $ex
    
        Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"

        throw "Error querying data from [$uri]. Error Message: $($errorMessage.AuditErrorMessage)"
    }
}
#endregion functions

# Query Persons
try {
    Write-Verbose "Querying Persons"

    $persons = [System.Collections.ArrayList]::new()
    Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Users_v2" -OrderByFieldIds "Medewerker" ([ref]$persons)

    # Sort on Medewerker (to make sure the order is always the same)
    $persons = $persons | Sort-Object -Property Medewerker

    Write-Information "Successfully queried Persons. Result count: $($persons.count)"
}
catch {
    $ex = $PSItem
    $errorMessage = Get-ErrorMessage -ErrorObject $ex

    Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"

    throw "Could not query Persons. Error Message: $($errorMessage.AuditErrorMessage)"
}

# Query OrganizationalUnits
try {
    Write-Verbose "Querying OrganizationalUnits"

    $organizationalUnits = [System.Collections.ArrayList]::new()
    Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_OrganizationalUnits_v2" -OrderByFieldIds "ExternalId" ([ref]$organizationalUnits)
    
    # #region Example to add boolean value if person is manager (more configuration required in person loop, see below) 1/2
    # $managersList = ($organizationalUnits | Group-Object ManagerExternalId).name | Sort-Object -Unique
    # #endregion Example to add boolean value if person is manager (more configuration required in person loop, see below) 1/2

    # Sort on ExternalId (to make sure the order is always the same)
    $organizationalUnits = $organizationalUnits | Sort-Object -Property ExternalId

    # Group on ExternalId (to match to employments and positions)
    $organizationalUnitsGrouped = $organizationalUnits | Group-Object ExternalId -AsString -AsHashTable

    # Group on ManagerExternalId (to match to person as manager to departments and calculate the field 'managerOf')
    $organizationalUnitsGroupedByManager = $organizationalUnits | Group-Object ManagerExternalId -AsString -AsHashTable

    Write-Information "Successfully queried OrganizationalUnits. Result count: $($organizationalUnits.count)"
}
catch {
    $ex = $PSItem
    $errorMessage = Get-ErrorMessage -ErrorObject $ex

    Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"

    throw "Could not query OrganizationalUnits. Error Message: $($errorMessage.AuditErrorMessage)"
}

# Query Employments
try {
    Write-Verbose "Querying Employments"

    $employments = [System.Collections.ArrayList]::new()
    Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Employments_v2" -OrderByFieldIds "ExternalID,Medewerker,Begindatum_functie" ([ref]$employments)

    # Sort on ExternalID (to make sure the order is always the same)
    $employments = $employments | Sort-Object -Property ExternalID

    # Add extra data to employment object
    $employments | Foreach-Object {
        # Add all organizational units (all "layers") to employment object
        $allDepartments = [System.Collections.ArrayList]::new()
        $deparmentId = [String]$_.Organisatorische_eenheid_code
        $department = $organizationalUnitsGrouped["$deparmentId"]
        if ($null -ne $department) {
            [void]$allDepartments.add($department)
            while (-NOT[String]::IsNullOrEmpty([String]$department.ParentExternalId)) {
                $deparmentParentId = $department.ParentExternalId
                if (-NOT[String]::IsNullOrEmpty([String]$deparmentParentId)) {
                    # In case multiple departments are found with same id, always select first we encounter
                    $department = $organizationalUnitsGrouped["$deparmentParentId"] | Select-Object -First 1
                    [void]$allDepartments.add($department)
                }
            }
        }
        # Add a single property with a comma seperated list of values to employment object
        $_ | Add-Member -MemberType NoteProperty -Name "All_Department_ExternalIds" -Value ('"{0}"' -f ($allDepartments.ExternalId -Join '","')) -Force
    }

    # Group on Medewerker (to match to medewerker)
    $employmentsGrouped = $employments | Group-Object Medewerker -AsHashTable

    Write-Information "Successfully queried Employments. Result count: $($employments.count)"
}
catch {
    $ex = $PSItem
    $errorMessage = Get-ErrorMessage -ErrorObject $ex

    Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"

    throw "Could not query Employments. Error Message: $($errorMessage.AuditErrorMessage)"
}

# Query Positions
if ($positionsAction -ne "onlyEmployments") {
    try {
        Write-Verbose "Querying Positions"

        $positions = [System.Collections.ArrayList]::new()
        Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Positions_v2" -OrderByFieldIds "ExternalID,EmploymentExternalID,Medewerker,Begindatum_functie" ([ref]$positions)

        # Sort on ExternalID (to make sure the order is always the same)
        $positions = $positions | Sort-Object -Property ExternalID

        # Add extra data to position object
        $positions | Foreach-Object {
            # Add all organizational units (all "layers") to position object
            $allDepartments = [System.Collections.ArrayList]::new()
            $deparmentId = [String]$_.Organisatorische_eenheid_code
            $department = $organizationalUnitsGrouped["$deparmentId"]
            if ($null -ne $department) {
                [void]$allDepartments.add($department)
                while (-NOT[String]::IsNullOrEmpty([String]$department.ParentExternalId)) {
                    $deparmentParentId = $department.ParentExternalId
                    if (-NOT[String]::IsNullOrEmpty([String]$deparmentParentId)) {
                        # In case multiple departments are found with same id, always select first we encounter
                        $department = $organizationalUnitsGrouped["$deparmentParentId"] | Select-Object -First 1
                        [void]$allDepartments.add($department)
                    }
                }
            }
            # Add a single property with a comma seperated list of values to position object
            $_ | Add-Member -MemberType NoteProperty -Name "All_Department_ExternalIds" -Value ('"{0}"' -f ($allDepartments.ExternalId -Join '","')) -Force
        }

        # Group on EmploymentExternalID (to match to employment)
        $positionsGrouped = $positions | Group-Object EmploymentExternalID -AsHashTable

        Write-Information "Successfully queried Positions. Result count: $($positions.count)"
    }
    catch {
        $ex = $PSItem
        $errorMessage = Get-ErrorMessage -ErrorObject $ex
    
        Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"
    
        throw "Could not query Positions. Error Message: $($errorMessage.AuditErrorMessage)"
    }
}

# # Example to add boolean values for each group membership 1/2
# try{
#     Write-Verbose "Querying Groups"

#     $groups = [System.Collections.ArrayList]::new()
#     Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Groups_v2" -OrderByFieldIds "GroupId" ([ref]$groups)

#     Write-Information "Successfully queried Groups. Result count: $($groups.count)"
# }
# catch {
#     $ex = $PSItem
#     $errorMessage = Get-ErrorMessage -ErrorObject $ex

#     Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"

#     throw "Could not query Groups. Error Message: $($errorMessage.AuditErrorMessage)"
# }

# try{
#     Write-Verbose "Querying UserGroups"

#     $userGroups = [System.Collections.ArrayList]::new()
#     Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_UserGroups_v2" -OrderByFieldIds "UserId" ([ref]$userGroups)

#     # Group on UserId (to match to user)
#     $userGroupsGrouped = $userGroups | Group-Object UserId -AsHashTable

#     Write-Information "Successfully queried UserGroups. Result count: $($userGroups.count)"
# }
# catch {
#     $ex = $PSItem
#     $errorMessage = Get-ErrorMessage -ErrorObject $ex

#     Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"

#     throw "Could not query UserGroups. Error Message: $($errorMessage.AuditErrorMessage)"
# }

# try {
#     Write-Verbose 'Enhancing person objects with groups'

#     # Enhance person object with properties for the groups
#     $allowedGroupIds = @("ABB","APL")

#     $groups | Where-Object {$_.GroupId -in $allowedGroupIds} | ForEach-Object {
#         $persons | Add-Member -MemberType NoteProperty -Name "Role_$($_.GroupId)" -Value $false -Force
#     }

#     Write-Information "Successfully enhanced person objects with groups"
# }
# catch {
#     $ex = $PSItem
#     $errorMessage = Get-ErrorMessage -ErrorObject $ex

#     Write-Verbose "Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"

#     throw "Could not enhance person objects with groups. Error Message: $($errorMessage.AuditErrorMessage)"
# }
# # End Example (more configuration required in person loop, see below) 1/2

try {
    Write-Verbose 'Enhancing and exporting person objects to HelloID'

    # Set counter to keep track of actual exported person objects
    $exportedPersons = 0

    # Enahnce person model with required properties
    $persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
    $persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force

    # Add additional properties to person
    $persons | Add-Member -MemberType NoteProperty -Name "ManagerOf" -Value $null -Force

    $persons | ForEach-Object {
        # Create person object to log on which person the error occurs
        $personInProcess = $_

        # Set required fields for HelloID
        $_.ExternalId = $_.Medewerker

        # Include ExternalId in DisplayName of HelloID Raw Data
        $_.DisplayNAme = $_.DisplayName + " ($($_.ExternalId))" 
    
        $contractsList = [System.Collections.ArrayList]::new()

        # Get employments for person
        $employments = $employmentsGrouped[$_.Medewerker]

        if ($positionsAction -eq "onlyEmployments") {
            if ($null -ne $employments) {
                # Create custom contract object to include prefix of properties
                $employments | ForEach-Object {
                    $employmentObject = [PSCustomObject]@{}
                    $_.psobject.properties | ForEach-Object {
                        $employmentObject | Add-Member -MemberType $_.MemberType -Name "empl_$($_.Name)" -Value $_.Value -Force
                    }
                    [Void]$contractsList.Add($employmentObject)
                }
            }
            else {
                Write-Warning "No employments found for person: $($_.ExternalId)"  
            }
        }
        else {
            if ($null -ne $employments) {
                $employments | ForEach-Object {
                    # Get positions for employment
                    $positions = $positionsGrouped[$_.ExternalID]

                    # Add position and employment data to contracts
                    if ($null -ne $positions) {
                        foreach ($position in $positions) {
                            # Create custom position object to include prefix in properties
                            $positionObject = [PSCustomObject]@{}

                            # Add employment object with prefix for property names
                            $_.psobject.properties | ForEach-Object {
                                $positionObject | Add-Member -MemberType $_.MemberType -Name "empl_$($_.Name)" -Value $_.Value -Force
                            }

                            # Add position object with prefix for property names
                            $position.psobject.properties | ForEach-Object {
                                $positionObject | Add-Member -MemberType $_.MemberType -Name "pos_$($_.Name)" -Value $_.Value -Force
                            }

                            # Add employment and position data to contracts
                            [Void]$contractsList.Add($positionObject)
                        }
                    }
                    else {
                        # Add employment only data to contracts (in case of employments without positions)
                        $employmentObject = [PSCustomObject]@{}
                        $_.psobject.properties | ForEach-Object {
                            $employmentObject | Add-Member -MemberType $_.MemberType -Name "empl_$($_.Name)" -Value $_.Value -Force
                        }

                        [Void]$contractsList.Add($employmentObject)
                    }
                }            
            }
            else {
                Write-Warning "No employments found for person: $($_.ExternalId)"  
            }
        }

        # Add Contracts to person
        if ($null -ne $contractsList) {
            ## This example can be used by the consultant if you want to filter out persons with an empty array as contract
            ## *** Please consult with the Tools4ever consultant before enabling this code. ***
            # if ($contractsList.Count -eq 0) {
            #     Write-Warning "Excluding person from export: $($_.ExternalId). Reason: Contracts is an empty array"
            #     return
            # }
            # else {
            $_.Contracts = $contractsList
            # }
        }
        ## This example can be used by the consultant if the date filters on the person/employment/positions do not line up and persons without a contract are added to HelloID
        ## *** Please consult with the Tools4ever consultant before enabling this code. ***    
        # else {
        #     Write-Warning "Excluding person from export: $($_.ExternalId). Reason: Person has no contract data"
        #     return
        # }

        ## Group membership example (person part) 2/2
        # if (-Not[String]::IsNullOrEmpty($_.Gebruiker)){
        #     $groupMemberships = $userGroupsGrouped[$_.Gebruiker]
        #     if ($null -ne $groupMemberships){
        #         foreach ($groupMembership in ($groupMemberships | Where-Object {$_.GroupId -in $allowedGroupIds}) ) {
        #             $_."Role_$($groupMembership.GroupId)" = $true
        #         }
        #     } else {
        #         Write-Verbose "Person $($_.Gebruiker) has no groupmembership (within specified allowed groups)"
        #     }
        # } else {
        #     Write-Verbose "User $($_.ExternalId) has no linked user"
        # }
        ## End Group membership example (person part) 2/2

        # #region Example to add boolean value if person is manager 2/2
        # if ($managersList -contains $_.ExternalId ) {
        #     $_ | Add-Member -MemberType NoteProperty -Name "isManager" -Value $true -Force
        # }
        # else {
        #     $_ | Add-Member -MemberType NoteProperty -Name "isManager" -Value $false -Force
        # }
        # #endregion Example to add boolean value if person is manager 2/2

        # Calculate and set the field 'managerOf'
        $organizationalUnitsPersonIsManagerOf = $null
        $organizationalUnitsPersonIsManagerOf = $organizationalUnitsGroupedByManager["$($_.ExternalId)"]
        if ($null -ne $organizationalUnitsPersonIsManagerOf ) {
            $_.ManagerOf = '"{0}"' -f ($organizationalUnitsPersonIsManagerOf.ExternalId -Join '","')
        }

        # Sanitize and export the json
        $person = $_ | ConvertTo-Json -Depth 10
        $person = $person.Replace("._", "__")
        $person = $person.Replace("E-mail", "Email") # HelloID doesn't support properties with '-' in the name, sanitize this

        Write-Output $person

        # Updated counter to keep track of actual exported person objects
        $exportedPersons++
    }
    Write-Information "Successfully enhanced and exported person objects to HelloID. Result count: $($exportedPersons)"
    Write-Information "Person import completed"
}
catch {
    $ex = $PSItem
    $errorMessage = Get-ErrorMessage -ErrorObject $ex

    # If debug logging is toggled, log on which person and line the error occurs
    if ($c.isDebug -eq $true) {
        Write-Warning "Error occurred for person [$($personInProcess.ExternalId)]. Error at Line [$($ex.InvocationInfo.ScriptLineNumber)]: $($ex.InvocationInfo.Line). Error: $($errorMessage.VerboseErrorMessage)"
    }
     
    throw "Could not enhance and export person objects to HelloID. Error Message: $($errorMessage.AuditErrorMessage)"
}
