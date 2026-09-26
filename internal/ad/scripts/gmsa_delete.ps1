$serverParams = Get-ServerParams
$gmsa = Get-GmsaOrNull ([string]$payload.guid)

if ($null -eq $gmsa) {
    [pscustomobject]@{ deleted = $false; exists = $false } | ConvertTo-Json -Compress
    return
}

if ([bool]$gmsa.ProtectedFromAccidentalDeletion) {
    Set-ADObject -Identity $gmsa.DistinguishedName -ProtectedFromAccidentalDeletion $false @serverParams -ErrorAction Stop
}

Remove-ADServiceAccount -Identity $gmsa.DistinguishedName -Confirm:$false @serverParams -ErrorAction Stop

[pscustomobject]@{ deleted = $true; exists = $false } | ConvertTo-Json -Compress
