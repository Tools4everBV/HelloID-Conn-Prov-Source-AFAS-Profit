# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

#Region Script
$c = $configuration | ConvertFrom-Json

$baseUri = $($c.BaseUrl)
$token = $($c.Token)
$positionsAction = $($c.onlyEmployments)

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
    }
    catch {
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
$employmentsGroupedByMedewerker = $employments | Group-Object Medewerker -AsHashTable
$employmentsGroupedByExternalid = $employments | Group-Object ExternalID -AsHashTable

if ($positionsAction -ne "onlyEmployments") {
    $positions = [System.Collections.ArrayList]::new()
    Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Positions_v2" ([ref]$positions)
    $positionsGrouped = $positions | Group-Object Medewerker -AsHashTable
}

### Example to add boolean values for each group membership 1/2
$groups = [System.Collections.ArrayList]::new()
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Groups_v2" ([ref]$groups)

$userGroups = [System.Collections.ArrayList]::new()
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_UserGroups_v2" ([ref]$userGroups)
$userGroupsGrouped = $userGroups | Group-Object UserId -AsHashTable

# Enhance person object with properties for the groups
$allowedGroupIds = @("ABB", "APL")
foreach ( $group in ($groups | Where-Object { $_.GroupId -in $allowedGroupIds }) ) {
    $persons | Add-Member -MemberType NoteProperty -Name "Role_$($group.GroupId)" -Value $false -Force
}
## End Example (more configuration required in person loop, see below) 1/2

# $persons = $persons | Where-Object {$_.Medewerker -eq "AndreO"}
$persons | ForEach-Object {
    # Set required fields for HelloID
    $_.ExternalId = $_.Medewerker

    # Get employments for person
    $employments = $employmentsGroupedByMedewerker[$_.Medewerker]

    if ($positionsAction -eq "onlyEmployments") {
        if ($null -ne $employments) {
            $_.Contracts = $employments
        }
        else {
            Write-Warning "No employments found for person: $($_.Medewerker)"  
        }
    }
    else {
        # Get positions for person
        $positions = $positionsGrouped[$_.Medewerker]

        if ($null -ne $positions) {
            foreach ($position in $positions) {
                # Get employment for positions
                if ($null -ne $position.EmploymentExternalID) {
                    [PsObject]$employmentForPosition = $employmentsGroupedByExternalid[$position.EmploymentExternalID]
                }

                if ($null -ne $employmentForPosition) {
                    if ($employmentForPosition.Count -eq 1) {
                        foreach ($employmentProperty in $employmentForPosition[0].psobject.properties) {
                            $position | Add-Member -MemberType $employmentProperty.MemberType -Name "empl_$($employmentProperty.Name)" -Value $employmentProperty.Value
                        }
                    }
                    else {
                        Write-Warning "Multiple employments found with externalId: $($position.EmploymentExternalID). This should not be possible."  
                    }
                }
                else {
                    Write-Verbose "No employment found with externalId: $($position.EmploymentExternalID)"  
                }
            }
            $_.Contracts += $position
        }
        else {
            Write-Warning "No positions found for person: $($_.Medewerker). Defaulting to employments"
            if ($null -ne $employments) {
                $_.Contracts = $employments
            }
            else {
                Write-Warning "No employments found for person: $($_.Medewerker)"  
            }
        }
    }

    ### Group membership example (person part) 2/2
    if (-Not[String]::IsNullOrEmpty($_.Gebruiker)) {
        $groupMemberships = $userGroupsGrouped[$_.Gebruiker]
        if ($null -ne $groupMemberships) {
            foreach ($groupMembership in ($groupMemberships | Where-Object { $_.GroupId -in $allowedGroupIds }) ) {
                $_."Role_$($groupMembership.GroupId)" = $true
            }
        }
        else {
            Write-Verbose "Person $($_.Gebruiker) has no groupmembership (within specified allowed groups)"
        }
    }
    else {
        Write-Verbose "User $($_.Medewerker) has no linked user"
    }
    ### End Group membership example (person part) 2/2

    ### This example can be used by the consultant if the date filters on the person/employment/positions do not line up and persons without a contract are added to HelloID
    ### *** Please consult with the Tools4ever consultant before enabling this code. ***
    if ($null -eq $_.Contracts) {
        Write-Warning "Excluding person from export: $($_.Medewerker). Reason: Person has no contract data"
        return
    }

    # Sanitize and export the json
    $person = $_ | ConvertTo-Json -Depth 10
    $person = $person.Replace("._", "__")

    Write-Output $person
}