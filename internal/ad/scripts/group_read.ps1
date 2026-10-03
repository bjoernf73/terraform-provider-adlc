$domainDN = Get-DomainDN

$guidBytes = ([guid]([string]$payload.guid)).ToByteArray()
$guidFilter = '(objectGUID=' + (ConvertTo-ADLCFilterBytes $guidBytes) + ')'
$attributes = @('name', 'sAMAccountName', 'description', 'displayName', 'mail', 'info', 'wWWHomePage', 'managedBy', 'groupType', 'objectGUID', 'objectSid')
$found = @(Search-ADLCEntries $domainDN $guidFilter ([System.DirectoryServices.Protocols.SearchScope]::Subtree) $attributes)

if ($found.Count -eq 0) {
    [pscustomobject]@{
        exists = $false
    } | ConvertTo-Json -Compress
    return
}

$group = $found[0]
$dn = [string]$group.DistinguishedName
$containerDN = Get-ParentDN $dn
$managedBy = Get-ADLCString $group 'managedBy'

# groupType is a bit flag: scope in the low bits, 0x80000000 marks a security group.
$groupType = [int64](Get-ADLCString $group 'groupType')
if ($groupType -band 0x8) { $scope = 'Universal' }
elseif ($groupType -band 0x4) { $scope = 'DomainLocal' }
else { $scope = 'Global' }
if ($groupType -band 0x80000000) { $category = 'Security' } else { $category = 'Distribution' }

# path and managed_by may be configured in a different but equivalent spelling; report whether
# the stored value matches so the provider can keep the user's spelling.
$pathMatch = $false
if ($null -ne $payload.path) {
    $pathMatch = ((Convert-PathToDN ([string]$payload.path) $domainDN) -eq $containerDN)
}

$managedByMatch = $false
if (-not [string]::IsNullOrWhiteSpace([string]$payload.managed_by)) {
    $resolved = Resolve-ADLCPrincipal ([string]$payload.managed_by) @('distinguishedName')
    if ($null -ne $resolved -and [string]$resolved.DistinguishedName -eq [string]$managedBy) {
        $managedByMatch = $true
    }
}

$security = Get-ADLCSecurityDescriptor $dn
$protected = Test-ADLCProtectedFromAccidentalDeletion $security

$managerCanUpdate = $false
if (-not [string]::IsNullOrWhiteSpace([string]$managedBy)) {
    $managerSid = Get-ADLCSid (Get-ADLCEntry -DistinguishedName ([string]$managedBy) -Attributes @('objectSid'))
    $managerCanUpdate = Test-ADLCMemberWriteGranted $security $managerSid
}

[pscustomobject]@{
    exists                             = $true
    name                               = Get-ADLCString $group 'name'
    sam_account_name                   = Get-ADLCString $group 'sAMAccountName'
    description                        = Get-ADLCString $group 'description'
    display_name                       = Get-ADLCString $group 'displayName'
    mail                               = Get-ADLCString $group 'mail'
    info                               = Get-ADLCString $group 'info'
    homepage                           = Get-ADLCString $group 'wWWHomePage'
    managed_by                         = [string]$managedBy
    managed_by_match                   = $managedByMatch
    manager_can_update_membership      = $managerCanUpdate
    protected_from_accidental_deletion = $protected
    category                           = $category
    scope                              = $scope
    path                               = Convert-DNToPath $containerDN $domainDN
    path_match                         = $pathMatch
    container_dn                       = $containerDN
    distinguished_name                 = $dn
    guid                               = Get-ADLCGuid $group
    sid                                = Get-ADLCSid $group
} | ConvertTo-Json -Compress
