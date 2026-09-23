$domainDN = Get-DomainDN
$segments = @([string]$payload.path -split '/' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
if ($segments.Count -eq 0) {
    throw 'path must contain at least one OU segment'
}

$serverParams = Get-ServerParams
$leafDN = Convert-PathToDN ([string]$payload.path) $domainDN

# Distinguished names of ancestor OUs this apply actually creates. The leaf is excluded
# because it is tracked separately via distinguished_name; pre-existing OUs are never added.
$createdOUs = New-Object System.Collections.Generic.List[string]

$parentDN = $domainDN
foreach ($segment in $segments) {
    $currentDN = 'OU=' + $segment + ',' + $parentDN

    $found = $true
    try {
        Get-ADObject -Identity $currentDN @serverParams -ErrorAction Stop | Out-Null
    }
    catch {
        if (-not (Test-IsIdentityNotFound $_)) {
            throw
        }

        $found = $false
    }

    if (-not $found) {
        try {
            New-ADOrganizationalUnit -Name $segment -Path $parentDN @serverParams -ErrorAction Stop | Out-Null
            if ($currentDN -ne $leafDN) {
                $createdOUs.Add($currentDN)
            }
        }
        catch {
            # A concurrent apply may have created it between the check and now; treat as pre-existing.
            if (-not (Test-IsIdentityAlreadyExists $_)) {
                throw
            }
        }
    }

    $parentDN = $currentDN
}

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
    created_organizational_units = @($createdOUs)
} | ConvertTo-Json -Compress
