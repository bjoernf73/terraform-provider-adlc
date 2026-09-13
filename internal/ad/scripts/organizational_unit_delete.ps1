$serverParams = Get-ServerParams
$leafDN = [string]$payload.distinguished_name

try {
    $null = Get-LeafOrganizationalUnit $leafDN
}
catch {
    if (Test-IsIdentityNotFound $_) {
        [pscustomobject]@{
            deleted = $false
            exists = $false
        } | ConvertTo-Json -Compress
        return
    }

    throw
}

Set-ADOrganizationalUnit -Identity $leafDN -ProtectedFromAccidentalDeletion:$false @serverParams -ErrorAction Stop

if ($payload.delete_subtree -eq $true) {
    Remove-ADOrganizationalUnit -Identity $leafDN -Recursive -Confirm:$false @serverParams -ErrorAction Stop
}
else {
    Remove-ADOrganizationalUnit -Identity $leafDN -Confirm:$false @serverParams -ErrorAction Stop
}

[pscustomobject]@{
    deleted = $true
    exists = $false
} | ConvertTo-Json -Compress
