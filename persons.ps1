#Region Script
$connectionSettings = ConvertFrom-Json $configuration

$baseUri = $($connectionSettings.BaseUrl)
$token = $($connectionSettings.Token)
$positionsAction = $($connectionSettings.positionsAction)

Write-Verbose -Verbose -Message "Start person import: Base URL: $baseUri, Using positions: $includePositions, token length: $($token.length)"
Write-Verbose -Verbose -Message "Using positionsAction: '$positionsAction'"

# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

function Get-AFASConnectorData {
    param(
        [parameter(Mandatory = $true)]$Token,
        [parameter(Mandatory = $true)]$BaseUri,
        [parameter(Mandatory = $true)]$Connector,
        [parameter(Mandatory = $true)][ref]$data
    )

    try {
        Write-Verbose -Verbose -Message "Starting downloading objects through get-connector '$connector'"
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
        Write-Verbose -Verbose -Message "Downloaded '$($data.Value.count)' records through get-connector '$connector'"
    } catch {
        $data.Value = $null
        Write-Verbose -Verbose -Message "Error occured while downloading data through get-connector '$connector': $($_.Exception.Message) - $($_.ScriptStackTrace)"
        Throw "A critical error occured. Please see the snapshot log for details..."
    }
}

$persons = [System.Collections.ArrayList]::new()
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Users_v2" ([ref]$persons)

$employments = [System.Collections.ArrayList]::new()
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Employments_v2" ([ref]$employments)
$employments | Add-Member -MemberType NoteProperty -Name "Type" -Value "employment" -Force
$employments = $employments | Group-Object Persoonsnummer -AsHashTable

### Example to add boolean values for each group membership
#$groups = [System.Collections.ArrayList]::new()
#Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Groups_v2" ([ref]$groups)
#$userGroups = [System.Collections.ArrayList]::new()
#Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_UserGroups_v2" ([ref]$userGroups)
# Group the group memberships
#foreach ($group in $groups) {
#    $persons | Add-Member -MemberType NoteProperty -Name "Role_$($group.groupId)" -Value $false -Force
#}
#$userGroups = $userGroups | Group-Object UserId -AsHashTable
## End Example (more configuration required in person loop, see below)

if ($true -eq $includePositions) {
    $positions = [System.Collections.ArrayList]::new()
    Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Positions_v2" ([ref]$positions)
    $positions | Add-Member -MemberType NoteProperty -Name "Type" -Value "position" -Force
    $positions = $positions | Group-Object Persoonsnummer -AsHashTable
}

# Extend the persons with positions and required fields
$persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force

$persons | ForEach-Object {
    $_.ExternalId = $_.Persoonsnummer
    $contracts = $employments[$_.Persoonsnummer]
    if ($null -ne $contracts) {
        $_.Contracts = $contracts
    }
    if($true -eq $includePositions) {
        $positionExtension = $positions[$_.Persoonsnummer]
        if ($null -ne $positionExtension) {
            $_.Contracts += $positionExtension
        }
    }

### Group membership example (person part)
#    $groupMemberships = $userGroups[$_.Gebruiker]

#    foreach ($groupMembership in $groupMemberships) {
#       $_."Role_$($groupMembership.GroupId)" = $True
#    }
### End Group membership example (person part)
}

# Make sure persons are unique
$persons = $persons | Sort-Object ExternalId -Unique

### This example can be used by the consultant if the date filters on the person/employment/positions do not line up and persons without a contract are added to HelloID
#Write-Verbose -Verbose -Message "Filtering out persons without contract data. Before: $($persons.count)"
#$persons = $persons | Where-Object contracts -ne $null
#Write-Verbose -Verbose -Message  "Filtered out persons without contract data. After: $($persons.count)"

# Export and sanitize the json
$json = $persons | ConvertTo-Json -Depth 10
$json = $json.Replace("._", "__")

Write-Output $json
Write-Verbose -Verbose -Message "End person import"