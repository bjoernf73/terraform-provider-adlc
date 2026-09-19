Import-Module ActiveDirectory -ErrorAction Stop

$guid = [string]$payload.guid
$adObject = Get-WmiFilterByGuid $guid
if ($null -ne $adObject) {
    $serverParams = Get-ServerParams
    Remove-ADObject -Identity $adObject.DistinguishedName -Confirm:$false @serverParams -ErrorAction Stop
}

[pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
