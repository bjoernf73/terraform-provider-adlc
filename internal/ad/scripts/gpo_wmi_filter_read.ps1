Import-Module ActiveDirectory -ErrorAction Stop

$serverParams = Get-ServerParams
$gpoGuid = [string]$payload.gpo_guid

$gpoObject = @(Get-ADObject -LDAPFilter "(&(objectClass=groupPolicyContainer)(name={$gpoGuid}))" -Properties gPCWQLFilter @serverParams -ErrorAction Stop)

if ($gpoObject.Count -eq 0 -or [string]::IsNullOrEmpty($gpoObject[0].gPCWQLFilter)) {
    [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
    return
}

$gpo = $gpoObject[0]

# gPCWQLFilter is formatted as "[<domainFQDN>;<filter CN>;0]".
$parts = $gpo.gPCWQLFilter.Trim('[', ']').Split(';')
$wmiFilterGuid = $parts[1] -replace '[{}]', ''

[pscustomobject]@{
    exists          = $true
    gpo_guid        = $gpoGuid
    wmi_filter_guid = $wmiFilterGuid
    gpo_dn          = $gpo.DistinguishedName
} | ConvertTo-Json -Compress
