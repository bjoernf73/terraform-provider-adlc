$serverParams = Get-ServerParams
$leafDN = [string]$payload.distinguished_name

$leafExisted = $true
try {
    $null = Get-LeafOrganizationalUnit $leafDN
}
catch {
    if (Test-IsIdentityNotFound $_) {
        $leafExisted = $false
    }
    else {
        throw
    }
}

if ($leafExisted) {
    Set-ADOrganizationalUnit -Identity $leafDN -ProtectedFromAccidentalDeletion:$false @serverParams -ErrorAction Stop

    if ($payload.delete_subtree -eq $true) {
        Remove-ADOrganizationalUnit -Identity $leafDN -Recursive -Confirm:$false @serverParams -ErrorAction Stop
    }
    else {
        Remove-ADOrganizationalUnit -Identity $leafDN -Confirm:$false @serverParams -ErrorAction Stop
    }
}

# Remove ancestor OUs this resource created, deepest first, but only while each is empty so a
# branch still holding other managed objects is never destroyed.
$createdOUs = @()
if (($payload.PSObject.Properties.Name -contains 'created_organizational_units') -and ($null -ne $payload.created_organizational_units)) {
    $createdOUs = @($payload.created_organizational_units)
}

if ($createdOUs.Count -gt 0) {
    [array]::Reverse($createdOUs)
    foreach ($dn in $createdOUs) {
        try {
            $null = Get-ADObject -Identity $dn @serverParams -ErrorAction Stop
        }
        catch {
            if (Test-IsIdentityNotFound $_) {
                continue
            }

            throw
        }

        $children = @(Get-ADObject -SearchBase $dn -SearchScope OneLevel -LDAPFilter '(objectClass=*)' @serverParams -ErrorAction Stop)
        if ($children.Count -gt 0) {
            continue
        }

        Set-ADOrganizationalUnit -Identity $dn -ProtectedFromAccidentalDeletion:$false @serverParams -ErrorAction Stop
        Remove-ADOrganizationalUnit -Identity $dn -Confirm:$false @serverParams -ErrorAction Stop
    }
}

[pscustomobject]@{
    deleted = $leafExisted
    exists = $false
} | ConvertTo-Json -Compress
