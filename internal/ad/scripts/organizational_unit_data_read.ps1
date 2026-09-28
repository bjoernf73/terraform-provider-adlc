$domainDN = Get-DomainDN
$dn = Convert-PathToDN ([string]$payload.path) $domainDN

try {
    $ou = Get-LeafOrganizationalUnit $dn
}
catch {
    if (Test-IsIdentityNotFound $_) {
        throw "organizational unit '$([string]$payload.path)' not found"
    }

    throw
}

[pscustomobject]@{
    path                               = Convert-DNToPath $ou.DistinguishedName $domainDN
    description                        = $ou.Description
    distinguished_name                 = $ou.DistinguishedName
    name                               = $ou.Name
    protected_from_accidental_deletion = [bool]$ou.ProtectedFromAccidentalDeletion
} | ConvertTo-Json -Compress
