$domainDN = Get-DomainDN

try {
    $ou = Get-LeafOrganizationalUnit ([string]$payload.distinguished_name)
    [pscustomobject]@{
        exists = $true
        path = Convert-DNToPath $ou.DistinguishedName $domainDN
        description = $ou.Description
        distinguished_name = $ou.DistinguishedName
        name = $ou.Name
    } | ConvertTo-Json -Compress
}
catch {
    if (Test-IsIdentityNotFound $_) {
        [pscustomobject]@{
            exists = $false
        } | ConvertTo-Json -Compress
    }
    else {
        throw
    }
}
