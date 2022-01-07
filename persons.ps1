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
$persons | Add-Member -MemberType NoteProperty -Name "Contracts" -Value $null -Force
$persons | Add-Member -MemberType NoteProperty -Name "ExternalId" -Value $null -Force

$employments = [System.Collections.ArrayList]::new()
Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Employments_v2" ([ref]$employments)
$employments = $employments | Group-Object Persoonsnummer -AsHashTable

if ($positionsAction -ne "onlyEmployments") {
    $positions = [System.Collections.ArrayList]::new()
    Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Positions_v2" ([ref]$positions)
    $positions = $positions | Group-Object EmploymentExternalID -AsHashTable
}



$persons | ForEach-Object {
    $_.ExternalId = $_.Persoonsnummer
    $employmentList = $employments[$_.Persoonsnummer]
    write-verbose -verbose $employmentList.Count
    if ($null -ne $employmentList) {
        if($positionsAction -eq "onlyEmployments") {
            $_.Contracts = $employmentList
        } else {
            foreach ($employment in $employmentList) {
                $positionList = $positions[$employment.externalId]
                write-verbose -verbose $positionList.Count
                if ($null -ne $positionExtension) {
                        # Do error action here (empty externalID so helloid generates a blocked person)
                        # Do not add contract, this should be enough in most implementations @Ramon, heb jij hier een slim idee?
                } else {
                    foreach ($position in $positionList) {
                        foreach ($propery in $employment.psobject.properties) {
                            Write-Verbose -Verbose "$(propery.MemberType), empl_$($propery.Name) $($propery.Value)"
                            $position | Add-Member -MemberType $propery.MemberType -Name "empl_$($propery.Name)" -Value $propery.Value
                        }
                    }
                    [void]$_.Contracts.value.Add($position)

                    # -and $positionsAction -eq "usePositionsErrorWhenMissing") {
                    # add position
                }
            }
        }
    } # TODO V2: else $contracts = []?

#### TODO V2: Must be moved to correct place
### Example to add boolean values for each group membership 1/2
### V2 TODO: Toevoegen van filter (array) van gebruikte groepen, zodat de RAW data niet ontploft
    #$groups = [System.Collections.ArrayList]::new()
    #Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_Groups_v2" ([ref]$groups)
    #$userGroups = [System.Collections.ArrayList]::new()
    #Get-AFASConnectorData -Token $token -BaseUri $baseUri -Connector "T4E_HelloID_UserGroups_v2" ([ref]$userGroups)
    # Group the group memberships
    #foreach ($group in $groups) {
    #    $persons | Add-Member -MemberType NoteProperty -Name "Role_$($group.groupId)" -Value $false -Force
    #}
    #$userGroups = $userGroups | Group-Object UserId -AsHashTable
## End Example (more configuration required in person loop, see below) 1/2


### Group membership example (person part) 2/2
    #    $groupMemberships = $userGroups[$_.Gebruiker]
    #    foreach ($groupMembership in $groupMemberships) {
    #       $_."Role_$($groupMembership.GroupId)" = $true
    #    }
### End Group membership example (person part) 2/2
}

# Make sure persons are unique
$persons = $persons | Sort-Object ExternalId -Unique

### This example can be used by the consultant if the date filters on the person/employment/positions do not line up and persons without a contract are added to HelloID
### *** Please consult with the Tools4ever consultant before enabling this code. ***
#Write-Verbose -Verbose -Message "Filtering out persons without contract data. Before: $($persons.count)"
#$persons = $persons | Where-Object contracts -ne $null
#Write-Verbose -Verbose -Message  "Filtered out persons without contract data. After: $($persons.count)"

# Export and sanitize the json
$json = $persons | ConvertTo-Json -Depth 10
$json = $json.Replace("._", "__")

Write-Output $json
Write-Verbose -Verbose -Message "End person import"