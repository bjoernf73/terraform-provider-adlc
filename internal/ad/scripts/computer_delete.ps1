$serverParams = Get-ServerParams
$computer = Get-ComputerOrNull ([string]$payload.guid)

if ($null -eq $computer) {
    [pscustomobject]@{ deleted = $false; exists = $false } | ConvertTo-Json -Compress
    return
}

if ([bool]$computer.ProtectedFromAccidentalDeletion) {
    Set-ADObject -Identity $computer.DistinguishedName -ProtectedFromAccidentalDeletion $false @serverParams -ErrorAction Stop
}

Remove-ADComputer -Identity $computer.DistinguishedName -Confirm:$false @serverParams -ErrorAction Stop

[pscustomobject]@{ deleted = $true; exists = $false } | ConvertTo-Json -Compress
