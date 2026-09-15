try {
    $user = Resolve-ADPrincipal ([string]$payload.user)
}
catch {
    [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
    return
}

[pscustomobject]@{
    exists       = $true
    user_dn      = $user.distinguishedName
    user_guid    = [string]$user.objectGUID
    pwd_last_set = Get-PasswordLastSet $user.distinguishedName
} | ConvertTo-Json -Compress
