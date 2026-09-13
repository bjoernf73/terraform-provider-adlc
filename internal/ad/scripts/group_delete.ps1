$serverParams = Get-ServerParams
$group = Get-GroupOrNull ([string]$payload.guid)

if ($null -eq $group) {
    [pscustomobject]@{
        deleted = $false
        exists  = $false
    } | ConvertTo-Json -Compress
    return
}

Set-ADObject -Identity $group.DistinguishedName -ProtectedFromAccidentalDeletion:$false @serverParams -ErrorAction Stop
Remove-ADGroup -Identity $group.DistinguishedName -Confirm:$false @serverParams -ErrorAction Stop

[pscustomobject]@{
    deleted = $true
    exists  = $false
} | ConvertTo-Json -Compress
