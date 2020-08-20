$token = "<provide XML token here>"
$baseUri = "https://<Provide Environment Id here>.rest.afas.online/profitrestservices";

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

            foreach ($record in $dataset.rows) { $data.Value.add($record) }

        }until([string]::IsNullOrEmpty($dataset.rows))
    } catch {
        $data.Value = $null
        Write-Verbose $_.Exception
    }
}

$organizationalUnits = New-Object System.Collections.ArrayList
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_OrganizationalUnits" ([ref]$organizationalUnits)

# Extend the organizationalUnits with required and additional fields
$organizationalUnits | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
$organizationalUnits | Add-Member -MemberType NoteProperty -Name "DisplayName" -Value $null -Force
$organizationalUnits | Add-Member -MemberType NoteProperty -Name "ManagerExternalId" -Value $null -Force
$organizationalUnits | Add-Member -MemberType NoteProperty -Name "ParentExternalId" -Value $null -Force
$organizationalUnits | ForEach-Object {
    $_.ExternalId = $_.UnitD
    $_.DisplayName = $_.UnitDesc
    $_.ManagerExternalId = $_.Leidinggevende
    $_.ParentExternalId = $_.UpperUnit;
}
# Export the json
$json = $organizationalUnits | ConvertTo-Json -Depth 3
Write-Output $json