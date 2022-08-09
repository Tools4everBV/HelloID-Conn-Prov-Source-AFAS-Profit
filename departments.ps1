# Set TLS to accept TLS, TLS 1.1 and TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls -bor [Net.SecurityProtocolType]::Tls11 -bor [Net.SecurityProtocolType]::Tls12

$VerbosePreference = "SilentlyContinue"
$InformationPreference = "Continue"
$WarningPreference = "Continue"

$c = $configuration | ConvertFrom-Json

$baseUri = $($c.BaseUrl)
$token = $($c.Token)

Write-Information "Start department import: Base URL: $baseUri, Using positionsAction: $positionsAction, token length: $($token.length)"

function Get-AFASConnectorData {
    param(
        [parameter(Mandatory = $true)]$Token,
        [parameter(Mandatory = $true)]$BaseUri,
        [parameter(Mandatory = $true)]$Connector,
        [parameter(Mandatory = $true)][ref]$data
    )

    try {
        Write-Verbose "Starting downloading objects through get-connector '$connector'"
        $encodedToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($Token))
        $authValue = "AfasToken $encodedToken"
        $Headers = @{ Authorization = $authValue }

        $take = 1000
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
        Write-Verbose "Downloaded '$($data.Value.count)' records through get-connector '$connector'"
    }
    catch {
        $data.Value = $null
        Write-Warning "Error occured while downloading data through get-connector '$connector': $($_.Exception.Message) - $($_.ScriptStackTrace)"
        Throw "A critical error occured. Please see the snapshot log for details..."
    }
}

# Query OrganizationalUnits
try {
    Write-Information 'Querying OrganizationalUnits'

    $organizationalUnits = [System.Collections.ArrayList]::new()
    Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_OrganizationalUnits_v2" ([ref]$organizationalUnits)
    
    # Sort on ExternalId (to make sure the order is always the same)
    $organizationalUnits = $organizationalUnits | Sort-Object -Property ExternalId
    Write-Information "Succesfully queried OrganizationalUnits. Result count: $($organizationalUnits.count)"
}
catch {
    throw "Could not query OrganizationalUnits. Error: $($_.Exception.Message)"
}

try {
    Write-Information 'Enhancing and exporting department objects to HelloID'

    # Set counter to keep track of actual exported department objects
    $exportedDepartments = 0

    $organizationalUnits | ForEach-Object {
        # Sanitize and export the json
        $organizationalUnit = $_ | ConvertTo-Json -Depth 10

        Write-Output $organizationalUnit

        # Updated counter to keep track of actual exported department objects
        $exportedDepartments++
    }
    Write-Information "Succesfully enhanced and exported department objects to HelloID. Result count: $($exportedDepartments)"
    Write-Information "Department import completed"
}
catch {
    $ex = $PSItem
    Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error message: $($ex)"
    throw "Could not enhance and exporte department objects to HelloID. Error: $($ex.Exception.Message)"
}