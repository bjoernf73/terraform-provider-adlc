$domainDN = Get-DomainDN

$guidBytes = ([guid]([string]$payload.guid)).ToByteArray()
$guidFilter = '(objectGUID=' + (ConvertTo-ADLCFilterBytes $guidBytes) + ')'
$attributes = @(
    'name', 'sAMAccountName', 'dNSHostName', 'description', 'displayName', 'location',
    'userPrincipalName', 'managedBy', 'servicePrincipalName', 'msDS-SupportedEncryptionTypes',
    'userAccountControl', 'operatingSystem', 'operatingSystemVersion', 'objectGUID', 'objectSid'
)
$found = @(Search-ADLCEntries $domainDN $guidFilter ([System.DirectoryServices.Protocols.SearchScope]::Subtree) $attributes)

if ($found.Count -eq 0) {
    [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
    return
}

$computer = $found[0]
$dn = [string]$computer.DistinguishedName
$containerDN = Get-ParentDN $dn

$actualSam = Get-ADLCString $computer 'sAMAccountName'
$strippedSam = Get-StrippedSam $actualSam
$samMatch = $false
if (-not [string]::IsNullOrWhiteSpace([string]$payload.sam_account_name)) {
    $samMatch = ((Get-StrippedSam ([string]$payload.sam_account_name)) -ieq $strippedSam)
}

$managedByDN = Get-ADLCString $computer 'managedBy'
$managedByMatch = $false
if (-not [string]::IsNullOrWhiteSpace([string]$payload.managed_by)) {
    $resolved = Resolve-ADLCPrincipal ([string]$payload.managed_by) @('distinguishedName')
    if ($null -ne $resolved -and [string]$resolved.DistinguishedName -eq [string]$managedByDN) {
        $managedByMatch = $true
    }
}

$pathMatch = $false
if ($null -ne $payload.path) {
    $pathMatch = ((Convert-PathToDN ([string]$payload.path) $domainDN) -eq $containerDN)
}

$uac = [int64](Get-ADLCString $computer 'userAccountControl')
$enabled = -not ($uac -band 0x2)
$trustedForDelegation = [bool]($uac -band 0x80000)
$accountNotDelegated = [bool]($uac -band 0x100000)

# kerberos_encryption_type and compound_identity_supported are both in
# msDS-SupportedEncryptionTypes: the low bits are the encryption types, 0x20000 is compound id.
$encTypesRaw = Get-ADLCString $computer 'msDS-SupportedEncryptionTypes'
$compoundIdentity = $false
if (-not [string]::IsNullOrWhiteSpace($encTypesRaw)) {
    $compoundIdentity = [bool]([int64]$encTypesRaw -band 0x20000)
}

$security = Get-ADLCSecurityDescriptor $dn
$protected = Test-ADLCProtectedFromAccidentalDeletion $security

[pscustomobject]@{
    exists                             = $true
    name                               = Get-ADLCString $computer 'name'
    sam_account_name                   = $actualSam
    sam_account_name_stripped          = $strippedSam
    sam_match                          = $samMatch
    dns_host_name                      = Get-ADLCString $computer 'dNSHostName'
    path                               = Convert-DNToPath $containerDN $domainDN
    path_match                         = $pathMatch
    container_dn                       = $containerDN
    distinguished_name                 = $dn
    guid                               = Get-ADLCGuid $computer
    sid                                = Get-ADLCSid $computer
    description                        = Get-ADLCString $computer 'description'
    display_name                       = Get-ADLCString $computer 'displayName'
    location                           = Get-ADLCString $computer 'location'
    user_principal_name                = Get-ADLCString $computer 'userPrincipalName'
    managed_by                         = [string]$managedByDN
    managed_by_match                   = $managedByMatch
    enabled                            = $enabled
    kerberos_encryption_type           = @(Convert-EncryptionTypesToTokens $encTypesRaw)
    service_principal_names            = @(Get-ADLCStrings $computer 'servicePrincipalName')
    trusted_for_delegation             = $trustedForDelegation
    account_not_delegated              = $accountNotDelegated
    compound_identity_supported        = $compoundIdentity
    operating_system                   = Get-ADLCString $computer 'operatingSystem'
    operating_system_version           = Get-ADLCString $computer 'operatingSystemVersion'
    protected_from_accidental_deletion = $protected
} | ConvertTo-Json -Compress -Depth 5
