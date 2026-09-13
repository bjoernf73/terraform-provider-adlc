$domainDN = Get-DomainDN
$serverParams = Get-ServerParams
$leafDN = [string]$payload.distinguished_name
$null = Get-LeafOrganizationalUnit $leafDN

if ($null -eq $payload.description -or [string]::IsNullOrWhiteSpace([string]$payload.description)) {
    Set-ADOrganizationalUnit -Identity $leafDN -Clear Description @serverParams -ErrorAction Stop
}
else {
    Set-ADOrganizationalUnit -Identity $leafDN -Description ([string]$payload.description) @serverParams -ErrorAction Stop
}

$ou = Get-LeafOrganizationalUnit $leafDN
[pscustomobject]@{
    exists = $true
    path = Convert-DNToPath $ou.DistinguishedName $domainDN
    description = $ou.Description
    distinguished_name = $ou.DistinguishedName
    name = $ou.Name
} | ConvertTo-Json -Compress
