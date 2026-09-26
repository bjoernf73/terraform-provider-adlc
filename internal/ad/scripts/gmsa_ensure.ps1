$domainDN = Get-DomainDN
$serverParams = Get-ServerParams
$containerDN = Convert-PathToDN ([string]$payload.path) $domainDN
$name = [string]$payload.name
$targetDN = 'CN=' + $name + ',' + $containerDN

$gmsa = Get-GmsaOrNull $targetDN
$setParams = Get-GmsaSetParams

if ($null -eq $gmsa) {
    # sAMAccountName is unique domain-wide; AD appends '$', so compare on the stripped form.
    $sam = $name
    if (-not [string]::IsNullOrWhiteSpace([string]$payload.sam_account_name)) {
        $sam = Get-StrippedSam ([string]$payload.sam_account_name)
    }

    $samWithSuffix = $sam + '$'
    $conflict = @(Get-ADServiceAccount -Filter 'SamAccountName -eq $samWithSuffix' @serverParams -ErrorAction Stop)
    if ($conflict.Count -gt 0) {
        throw "a service account with sAMAccountName '$samWithSuffix' already exists at '$($conflict[0].DistinguishedName)'"
    }

    $newParams = @{
        Name           = $name
        SamAccountName = $sam
        Path           = $containerDN
    }

    if ($null -ne $payload.managed_password_interval_days -and [int]$payload.managed_password_interval_days -gt 0) {
        $newParams.ManagedPasswordIntervalInDays = [int]$payload.managed_password_interval_days
    }

    New-ADServiceAccount @newParams @setParams @serverParams -ErrorAction Stop | Out-Null
    $gmsa = Get-GmsaByIdentity $targetDN
}
else {
    # Adopt an existing account at the same DN and reconcile it to the configuration.
    Set-ADServiceAccount -Identity $gmsa.DistinguishedName @setParams @serverParams -ErrorAction Stop
    $gmsa = Get-GmsaByIdentity $gmsa.DistinguishedName
}

Set-GmsaMultiValued $gmsa.DistinguishedName
$gmsa = Get-GmsaByIdentity $gmsa.DistinguishedName

Sync-GmsaProtection $gmsa.DistinguishedName ([bool]$gmsa.ProtectedFromAccidentalDeletion)
$gmsa = Get-GmsaByIdentity $gmsa.DistinguishedName

Get-GmsaResult $gmsa $domainDN | ConvertTo-Json -Compress -Depth 5
