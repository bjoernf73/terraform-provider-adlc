$domainDN = Get-DomainDN
$segments = @([string]$payload.path -split '/' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
if ($segments.Count -eq 0) {
    throw 'path must contain at least one OU segment'
}

$serverParams = Get-ServerParams
$parentDN = $domainDN
foreach ($segment in $segments) {
    $currentDN = 'OU=' + $segment + ',' + $parentDN

    try {
        Get-ADObject -Identity $currentDN @serverParams -ErrorAction Stop | Out-Null
    }
    catch {
        if (-not (Test-IsIdentityNotFound $_)) {
            throw
        }

        New-ADOrganizationalUnit -Name $segment -Path $parentDN @serverParams -ErrorAction Stop | Out-Null
    }

    $parentDN = $currentDN
}

$leafDN = Convert-PathToDN ([string]$payload.path) $domainDN
if ($payload.PSObject.Properties.Name -contains 'description') {
    if ($null -eq $payload.description -or [string]::IsNullOrWhiteSpace([string]$payload.description)) {
        Set-ADOrganizationalUnit -Identity $leafDN -Clear Description @serverParams -ErrorAction Stop
    }
    else {
        Set-ADOrganizationalUnit -Identity $leafDN -Description ([string]$payload.description) @serverParams -ErrorAction Stop
    }
}

$ou = Get-LeafOrganizationalUnit $leafDN
[pscustomobject]@{
    exists = $true
    path = Convert-DNToPath $ou.DistinguishedName $domainDN
    description = $ou.Description
    distinguished_name = $ou.DistinguishedName
    name = $ou.Name
} | ConvertTo-Json -Compress
