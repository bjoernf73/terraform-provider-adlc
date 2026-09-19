Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop

$serverParams = Get-ServerParams
$gpo = Resolve-GPOIdentity ([string]$payload.gpo)

$filterIdentity = [string]$payload.wmi_filter
$parsedGuid = [guid]::Empty
if ([guid]::TryParse($filterIdentity, [ref]$parsedGuid)) {
    $filterObject = Get-WmiFilterByGuid $filterIdentity
}
else {
    $filterObject = Get-WmiFilterByName $filterIdentity
}
if ($null -eq $filterObject) {
    throw "WMI filter '$filterIdentity' was not found"
}

$domainFQDN = (Get-ADDomain @serverParams -ErrorAction Stop).DNSRoot
$gPCWQLFilterValue = "[$domainFQDN;$($filterObject.Name);0]"

$gpoObject = Get-ADObject -LDAPFilter "(&(objectClass=groupPolicyContainer)(name={$($gpo.Id.ToString())}))" -Properties gPCWQLFilter @serverParams -ErrorAction Stop

if ($null -eq $gpoObject.gPCWQLFilter) {
    Set-ADObject -Identity $gpoObject.DistinguishedName -Add @{ gPCWQLFilter = $gPCWQLFilterValue } @serverParams -ErrorAction Stop
}
else {
    Set-ADObject -Identity $gpoObject.DistinguishedName -Replace @{ gPCWQLFilter = $gPCWQLFilterValue } @serverParams -ErrorAction Stop
}

[pscustomobject]@{
    exists          = $true
    gpo_guid        = $gpo.Id.ToString()
    wmi_filter_guid = ([string]$filterObject.'msWMI-ID' -replace '[{}]', '')
    gpo_dn          = $gpoObject.DistinguishedName
} | ConvertTo-Json -Compress
