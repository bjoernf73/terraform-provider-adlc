$domainDN = Get-DomainDN
$serverParams = Get-ServerParams
$containerDN = Convert-PathToDN ([string]$payload.path) $domainDN
$targetDN = 'CN=' + [string]$payload.name + ',' + $containerDN

$user = Get-UserOrNull $targetDN
$setParams = Get-UserSetParams

if ($null -eq $user) {
    # sAMAccountName and userPrincipalName are unique domain-wide; report conflicts clearly.
    $samAccountName = [string]$payload.sam_account_name
    $conflict = @(Get-ADUser -Filter 'SamAccountName -eq $samAccountName' @serverParams -ErrorAction Stop)
    if ($conflict.Count -gt 0) {
        throw "a user with sAMAccountName '$samAccountName' already exists at '$($conflict[0].DistinguishedName)'"
    }

    $newParams = @{
        Name              = [string]$payload.name
        SamAccountName    = $samAccountName
        UserPrincipalName = [string]$payload.user_principal_name
        Path              = $containerDN
    }

    # No AccountPassword is set here, so an empty password fails complexity checks if the
    # account is created enabled. Force disabled at creation; adlc_user_password (or a later
    # apply, once a real password exists) reconciles Enabled to the configured value.
    $createSetParams = $setParams.Clone()
    $createSetParams.Enabled = $false

    New-ADUser @newParams @createSetParams @serverParams -ErrorAction Stop | Out-Null
    $user = Get-UserByIdentity $targetDN
}
else {
    # Adopt an existing user at the same DN and reconcile it to the configuration.
    Set-ADUser -Identity $user.DistinguishedName @setParams @serverParams -ErrorAction Stop

    if ([string]$user.UserPrincipalName -ne [string]$payload.user_principal_name) {
        Set-ADUser -Identity $user.DistinguishedName -UserPrincipalName ([string]$payload.user_principal_name) @serverParams -ErrorAction Stop
    }

    $user = Get-UserByIdentity $user.DistinguishedName
}

Sync-UserProtection $user.DistinguishedName ([bool]$user.ProtectedFromAccidentalDeletion)
$user = Get-UserByIdentity $user.DistinguishedName

Get-UserResult $user $domainDN | ConvertTo-Json -Compress
