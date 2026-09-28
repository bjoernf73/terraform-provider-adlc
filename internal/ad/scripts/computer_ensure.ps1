$domainDN = Get-DomainDN
$serverParams = Get-ServerParams
$containerDN = Convert-PathToDN ([string]$payload.path) $domainDN
$name = [string]$payload.name
$targetDN = 'CN=' + $name + ',' + $containerDN

$computer = Get-ComputerOrNull $targetDN
$setParams = Get-ComputerSetParams

if ($null -eq $computer) {
    # sAMAccountName is unique domain-wide; AD appends '$', so compare on the stripped form.
    $sam = $name
    if (-not [string]::IsNullOrWhiteSpace([string]$payload.sam_account_name)) {
        $sam = Get-StrippedSam ([string]$payload.sam_account_name)
    }

    $samWithSuffix = $sam + '$'
    $conflict = @(Get-ADComputer -Filter 'SamAccountName -eq $samWithSuffix' @serverParams -ErrorAction Stop)
    if ($conflict.Count -gt 0) {
        throw "a computer with sAMAccountName '$samWithSuffix' already exists at '$($conflict[0].DistinguishedName)'"
    }

    $newParams = @{
        Name           = $name
        SamAccountName = $sam
        Path           = $containerDN
    }

    New-ADComputer @newParams @setParams @serverParams -ErrorAction Stop | Out-Null
    $computer = Get-ComputerByIdentity $targetDN
}
else {
    # Adopt an existing account at the same DN and reconcile it to the configuration.
    Set-ADComputer -Identity $computer.DistinguishedName @setParams @serverParams -ErrorAction Stop
    $computer = Get-ComputerByIdentity $computer.DistinguishedName
}

Set-ComputerMultiValued $computer.DistinguishedName
$computer = Get-ComputerByIdentity $computer.DistinguishedName

Sync-ComputerProtection $computer.DistinguishedName ([bool]$computer.ProtectedFromAccidentalDeletion)
$computer = Get-ComputerByIdentity $computer.DistinguishedName

Get-ComputerResult $computer $domainDN | ConvertTo-Json -Compress -Depth 5
