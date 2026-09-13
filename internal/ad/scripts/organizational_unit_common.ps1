# Organizational unit helpers. Requires common.ps1.
function Get-LeafOrganizationalUnit([string]$DistinguishedName) {
    $serverParams = Get-ServerParams
    return Get-ADOrganizationalUnit -Identity $DistinguishedName -Properties Description, DistinguishedName, Name @serverParams -ErrorAction Stop
}
