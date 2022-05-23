# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$c = $configuration | ConvertFrom-Json

$baseUri = $($c.BaseUrl)
$token = $($c.Token)
$positionsAction = $($c.positionsAction)

Write-Information "Start person import: Base URL: $baseUri, Using positionsAction: $positionsAction, token length: $($token.length)"

function Get-AFASConnectorData {
    param(
        [parameter(Mandatory = $true)]$Token,
        [parameter(Mandatory = $true)]$BaseUri,
        [parameter(Mandatory = $true)]$Connector,
        [parameter(Mandatory = $true)][ref]$data
    )

    try {
        Write-Information "Starting downloading objects through get-connector '$connector'"
        $encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Token))
        $authValue = "AfasToken $encodedToken"
        $Headers = @{ Authorization = $authValue }

        $take = 100
        $skip = 0

        $uri = $BaseUri + "/connectors/" + $Connector + "?skip=$skip&take=$take"
        $dataset = Invoke-RestMethod -Method Get -Uri $uri -Headers $Headers -UseBasicParsing

        foreach ($record in $dataset.rows) { [void]$data.Value.add($record) }

        $skip += $take
        while (@($dataset.rows).count -eq $take) {
            $uri = $BaseUri + "/connectors/" + $Connector + "?skip=$skip&take=$take"

            $dataset = Invoke-RestMethod -Method Get -Uri $uri -Headers $Headers -UseBasicParsing

            $skip += $take

            foreach ($record in $dataset.rows) { [void]$data.Value.add($record) }
        }
        Write-Information "Downloaded '$($data.Value.count)' records through get-connector '$connector'"
    } catch {
        $data.Value = $null
        Write-Warning "Error occured while downloading data through get-connector '$connector': $($_.Exception.Message) - $($_.ScriptStackTrace)"
        Throw "A critical error occured. Please see the snapshot log for details..."
    }
}

$persons = [System.Collections.ArrayList]::new()
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Users_v2" ([ref]$persons)
$persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force

$employments = [System.Collections.ArrayList]::new()
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Employments_v2" ([ref]$employments)
$employmentsGrouped = $employments | Group-Object Medewerker -AsHashTable

if ($positionsAction -ne "onlyEmployments") {
    $positions = [System.Collections.ArrayList]::new()
    Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Positions_v2" ([ref]$positions)
    $positionsGrouped = $positions | Group-Object EmploymentExternalID -AsHashTable
}

### Example to add boolean values for each group membership 1/2
# $groups = [System.Collections.ArrayList]::new()
# Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Groups_v2" ([ref]$groups)

# $userGroups = [System.Collections.ArrayList]::new()
# Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_UserGroups_v2" ([ref]$userGroups)
# $userGroupsGrouped = $userGroups | Group-Object UserId -AsHashTable

# #Enhance person object with properties for the groups
# $allowedGroupIds = @("ABB","APL")

# $groups | Where-Object {$_.GroupId -in $allowedGroupIds} | ForEach-Object {
#    $persons | Add-Member -MemberType NoteProperty -Name "Role_$($_.GroupId)" -Value $false -Force
# }
## End Example (more configuration required in person loop, see below) 1/2

# $persons = $persons | Where-Object {$_.Medewerker -eq "CarolaZ"}
$persons | ForEach-Object {
    # Set required fields for HelloID
    $_.ExternalId = $_.Medewerker

    # Include ExternalId in DisplayName of HelloID Raw Data
    $_.DisplayNAme = $_.DisplayName + "($($_.ExternalId))" 

    $contractsList = [System.Collections.ArrayList]::new()

    # Get employments for person
    $employments = $employmentsGrouped[$_.Medewerker]

    if($positionsAction -eq "onlyEmployments") {
        if ($null -ne $employments) {
            # Create custom contract object to include prefix of properties
            $employments | ForEach-Object {
                $employmentObject = [PSCustomObject]@{}
                $_.psobject.properties | ForEach-Object {
                    $employmentObject | Add-Member -MemberType $_.MemberType -Name "empl_$($_.Name)" -Value $_.Value -Force
                }
                [Void]$contractsList.Add($employmentObject)
            }
        } else {
            Write-Warning "No employments found for person: $($_.Medewerker)"  
        }
    }else {
        if ($null -ne $employments) {
            $employments | ForEach-Object {
                # Get positions for employment
                $positions = $positionsGrouped[$_.ExternalID]

                # Add position and employment data to contracts
                if ($null -ne $positions){
                    foreach($position in $positions){
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
                } else {
                    # Add employment only data to contracts (in case of employments without positions)
                    $employmentObject = [PSCustomObject]@{}
                    $_.psobject.properties | ForEach-Object {
                        $employmentObject | Add-Member -MemberType $_.MemberType -Name "empl_$($_.Name)" -Value $_.Value -Force
                    }

                    [Void]$contractsList.Add($employmentObject)
                }
            }            
        } else {
            Write-Warning "No employments found for person: $($_.Medewerker)"  
        }
    }

    # Add Contracts to person
    if($null -ne $contractsList){
        $_.Contracts = $contractsList
    } else {
        ### This example can be used by the consultant if the date filters on the person/employment/positions do not line up and persons without a contract are added to HelloID
        ### *** Please consult with the Tools4ever consultant before enabling this code. ***
        # Write-Warning "Excluding person from export: $($_.Medewerker). Reason: Person has no contract data"
        # return
    }

    ### Group membership example (person part) 2/2
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
    #     Write-Verbose "User $($_.Medewerker) has no linked user"
    # }
    ### End Group membership example (person part) 2/2

    # Sanitize and export the json
    $person = $_ | ConvertTo-Json -Depth 10
    $person = $person.Replace("._", "__")

    Write-Output $person
}
