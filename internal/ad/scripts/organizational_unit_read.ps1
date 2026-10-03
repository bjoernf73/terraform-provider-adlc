$domainDN = Get-DomainDN

$entry = Get-ADLCEntry -DistinguishedName ([string]$payload.distinguished_name) -Attributes @('description', 'name') -Filter '(objectClass=organizationalUnit)'

if ($null -eq $entry) {
    [pscustomobject]@{
        exists = $false
    } | ConvertTo-Json -Compress
}
else {
    $dn = [string]$entry.DistinguishedName
    [pscustomobject]@{
        exists             = $true
        path               = Convert-DNToPath $dn $domainDN
        description        = Get-ADLCString $entry 'description'
        distinguished_name = $dn
        name               = Get-ADLCString $entry 'name'
    } | ConvertTo-Json -Compress
}
