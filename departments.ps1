#Region Script
$connectionSettings = ConvertFrom-Json $configuration

$baseUri = $($connectionSettings.BaseUrl)
$token = $($connectionSettings.Token)

# Enable TLS 1.2
if ([Net.ServicePointManager]::SecurityProtocol -notmatch "Tls12") {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

function Get-AFASConnectorData
{
    param(
        [parameter(Mandatory=$true)]$Token,
        [parameter(Mandatory=$true)]$BaseUri,
        [parameter(Mandatory=$true)]$Connector,
        [parameter(Mandatory=$true)][ref]$data
    )

    try {
        $encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Token))
        $authValue = "AfasToken $encodedToken"
        $Headers = @{ Authorization = $authValue }

        $take = 100
        $skip = 0

        $uri = $BaseUri + "/connectors/" + $Connector + "?skip=$skip&take=$take"
        $counter = 0 
        do {
            if ($counter -gt 0) {
                $skip += 100
                $uri = $BaseUri + "/connectors/" + $Connector + "?skip=$skip&take=$take"
            }    
            $counter++
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
            $dataset = Invoke-RestMethod -Method GET -Uri $uri -ContentType "application/json" -Headers $Headers -UseBasicParsing

            foreach ($record in $dataset.rows) { $null = $data.Value.add($record) }

        }until([string]::IsNullOrEmpty($dataset.rows))
    } catch {
        $data.Value = $null
        Write-Verbose $_.Exception
    }
}

$organizationalUnits = New-Object System.Collections.ArrayList
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_OrganizationalUnits" ([ref]$organizationalUnits)

# Export the json
$json = $organizationalUnits | ConvertTo-Json -Depth 3
Write-Output $json