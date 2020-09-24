#$token = "<provide XML token here>"
#$baseUri = "https://<Provide Environment Id here>.rest.afas.online/profitrestservices";

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

$persons = New-Object System.Collections.ArrayList
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Users" ([ref]$persons)

$employments = New-Object System.Collections.ArrayList
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Employments" ([ref]$employments)

<<<<<<< HEAD
# Group the employments
$employments = $employments | Group-Object Nummer -AsHashTable
=======
if ($useFormations -eq $true) {
    $formations = New-Object System.Collections.ArrayList
    Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Formatieverdeling" ([ref]$formations)
    $formations = $formations | Group-Object FN_GUID -AsHashTable
}

$costcenters = New-Object System.Collections.ArrayList
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Costcenters" ([ref]$costcenters)

$organizationalUnits = New-Object System.Collections.ArrayList
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_OrganizationalUnits" ([ref]$organizationalUnits)

# Group the data for processing
$organizationalUnits = $organizationalUnits | Group-Object Unitd -AsHashTable

$contractList = @();
if ($useFormations -eq $true) {
    foreach ($data in $employeeData) {
        
        if($data.FN_GUID){
            $formationData = $formations[$data.FN_GUID] | Sort-Object -Descending FV_Volgnummer
            foreach ($formation in $formationData) {
                $Contract = [PSCustomObject]@{
                    ExternalId = $formation.FV_GUID
                    Medewerker = $data.Medewerker
                }

                $Contract | Add-Member -MemberType NoteProperty -Name "Data" -Value $null -Force
                $Contract.Data = $data;

                $Contract | Add-Member -MemberType NoteProperty -Name "Formatie" -Value $null -Force
                $Contract.Formatie = $formation;

                $Contract | Add-Member -MemberType NoteProperty -Name "DepartmentDesc" -Value $null -Force
                $organizationalUnit = $organizationalUnits[$formation.FV_OE] | Select-Object -First 1
                if ($organizationalUnit -ne $null) {
                    $Contract.DepartmentDesc = $organizationalUnit.UnitDesc
                }
                $Contract | Add-Member -MemberType NoteProperty -Name "CostcenterDesc" -Value $null -Force
                $costcenter = $costcenters[$data.DV_Werkgever, $formation.FV_Kostenplaats] | Select-Object -First 1
                if ($costcenter -ne $null) {
                    $Contract.CostcenterDesc = $costcenter.Omschrijving
                }
                $contractList += $Contract
            }     
        }  
    }
} 
else {
    $employeeData | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force
    $employeeData | Add-Member -MemberType NoteProperty -Name "DepartmentDesc" -Value $null -Force
    $employeeData | Add-Member -MemberType NoteProperty -Name "CostcenterDesc" -Value $null -Force
    $employeeData | ForEach-Object {
        $_.ExternalId = $_.FN_GUID
        $organizationalUnit = $organizationalUnits[$_.FN_Type_functie] | Select-Object -First 1
        if ($organizationalUnit -ne $null) {
            $_.DepartmentDesc = $organizationalUnit.UnitDesc
        }
        $costcenter = $costcenters[$_.DV_Werkgever, $_.FN_Kostenplaats] | Select-Object -First 1
        if ($costcenter -ne $null) {
            $_.CostcenterDesc = $costcenter.Omschrijving
        }
    }
    $contractList += $employeeData
}

# Group the resulting positions
$contractList = $contractList | Group-Object Medewerker -AsHashTable
>>>>>>> 284f4aff64d0cc077ca8827f8ad5bc6886235424

# Extend the persons with positions and required fields
$persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force

$persons | ForEach-Object {
    $_.ExternalId = $_.Nummer
    $contracts = $employments[$_.Nummer]
    if ($null -ne $contracts) {
        $_.Contracts = $contracts
    }
    if ([string]::IsNullOrEmpty($_.Roepnaam) -eq $true) {
        $_.Roepnaam = "nvt"
    }
    if ([string]::IsNullOrEmpty($_.Geboortenaam) -eq $true) {
        $_.Geboortenaam = "nvt"
    }
    if ([string]::IsNullOrEmpty($_.Voornaam) -eq $true) {
        $_.Voornaam = "nvt"
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