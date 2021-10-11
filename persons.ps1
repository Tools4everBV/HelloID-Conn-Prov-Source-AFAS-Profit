#Region Script
$connectionSettings = ConvertFrom-Json $configuration

$baseUri = $($connectionSettings.BaseUrl)
$token = $($connectionSettings.Token)
$includePositions = $($connectionSettings.switchIncludePositions)

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
    }
    catch {
        $data.Value = $null
        Write-Verbose $_.Exception -Verbose
    }
}

$persons = New-Object System.Collections.ArrayList
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Users" ([ref]$persons)

$employments = New-Object System.Collections.ArrayList
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Employments" ([ref]$employments)

# Group the employments
$employments = $employments | Group-Object Persoonsnummer -AsHashTable

if($true -eq $includePositions)
{
    $positions = New-Object System.Collections.ArrayList
    Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Positions" ([ref]$positions)

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
    if($true -eq $includePositions)
    {
        $positionExtension = $positions[$_.Persoonsnummer]
        if ($null -ne $positionExtension) {
            $_.Contracts += $positionExtension
        }
    }
    if ($_.Naamgebruik_code -eq "0") {
        $_.Naamgebruik_code = "B"
    }
    if ($_.Naamgebruik_code -eq "1") {
        $_.Naamgebruik_code = "PB"
    }
    if ($_.Naamgebruik_code -eq "2") {
        $_.Naamgebruik_code = "P"
    }
    if ($_.Naamgebruik_code -eq "3") {
        $_.Naamgebruik_code = "BP"
    }
}

# Make sure persons are unique
$persons = $persons | Sort-Object ExternalId -Unique

# Export and sanitize the json
$json = $persons | ConvertTo-Json -Depth 10
$json = $json.Replace("._", "__")

Write-Output $json