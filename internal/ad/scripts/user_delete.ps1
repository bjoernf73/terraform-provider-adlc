$serverParams = Get-ServerParams
$user = Get-UserOrNull ([string]$payload.guid)

if ($null -eq $user) {
    [pscustomobject]@{ deleted = $false; exists = $false } | ConvertTo-Json -Compress
    return
}

if ([bool]$user.ProtectedFromAccidentalDeletion) {
    Set-ADObject -Identity $user.DistinguishedName -ProtectedFromAccidentalDeletion $false @serverParams -ErrorAction Stop
}

Remove-ADUser -Identity $user.DistinguishedName -Confirm:$false @serverParams -ErrorAction Stop

[pscustomobject]@{ deleted = $true; exists = $false } | ConvertTo-Json -Compress
