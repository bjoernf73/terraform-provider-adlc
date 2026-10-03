$domainDN = Get-DomainDN

$guidBytes = ([guid]([string]$payload.guid)).ToByteArray()
$guidFilter = '(objectGUID=' + (ConvertTo-ADLCFilterBytes $guidBytes) + ')'
$attributes = @(
    'name', 'sAMAccountName', 'userPrincipalName', 'description', 'displayName', 'givenName',
    'sn', 'initials', 'middleName', 'mail', 'physicalDeliveryOfficeName', 'telephoneNumber',
    'homePhone', 'mobile', 'facsimileTelephoneNumber', 'wWWHomePage', 'streetAddress',
    'postOfficeBox', 'l', 'st', 'postalCode', 'c', 'company', 'department', 'division', 'o',
    'employeeID', 'employeeNumber', 'title', 'homeDirectory', 'homeDrive', 'userWorkstations',
    'scriptPath', 'profilePath', 'accountExpires', 'manager', 'userAccountControl',
    'objectGUID', 'objectSid'
)
$found = @(Search-ADLCEntries $domainDN $guidFilter ([System.DirectoryServices.Protocols.SearchScope]::Subtree) $attributes)

if ($found.Count -eq 0) {
    [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
    return
}

$user = $found[0]
$dn = [string]$user.DistinguishedName
$containerDN = Get-ParentDN $dn
$managerDN = Get-ADLCString $user 'manager'

# Account-control flags live in the userAccountControl bit field.
$uac = [int64](Get-ADLCString $user 'userAccountControl')
$enabled = -not ($uac -band 0x2)
$passwordNeverExpires = [bool]($uac -band 0x10000)
$smartCardRequired = [bool]($uac -band 0x40000)
$trustedForDelegation = [bool]($uac -band 0x80000)

# accountExpires is a FILETIME; 0 and the max value both mean "never".
$accountExpirationDate = $null
$accountExpiresRaw = Get-ADLCString $user 'accountExpires'
if (-not [string]::IsNullOrWhiteSpace($accountExpiresRaw)) {
    $accountExpires = [int64]$accountExpiresRaw
    if ($accountExpires -ne 0 -and $accountExpires -ne 9223372036854775807) {
        $accountExpirationDate = [DateTime]::FromFileTime($accountExpires).ToString('yyyy-MM-dd')
    }
}

$pathMatch = $false
if ($null -ne $payload.path) {
    $pathMatch = ((Convert-PathToDN ([string]$payload.path) $domainDN) -eq $containerDN)
}

$managerMatch = $false
if (-not [string]::IsNullOrWhiteSpace([string]$payload.manager)) {
    $resolved = Resolve-ADLCPrincipal ([string]$payload.manager) @('distinguishedName')
    if ($null -ne $resolved -and [string]$resolved.DistinguishedName -eq [string]$managerDN) {
        $managerMatch = $true
    }
}

$security = Get-ADLCSecurityDescriptor $dn
$protected = Test-ADLCProtectedFromAccidentalDeletion $security
$cannotChangePassword = Test-ADLCCannotChangePassword $security

[pscustomobject]@{
    exists                             = $true
    name                               = Get-ADLCString $user 'name'
    sam_account_name                   = Get-ADLCString $user 'sAMAccountName'
    user_principal_name                = Get-ADLCString $user 'userPrincipalName'
    path                               = Convert-DNToPath $containerDN $domainDN
    path_match                         = $pathMatch
    container_dn                       = $containerDN
    distinguished_name                 = $dn
    guid                               = Get-ADLCGuid $user
    sid                                = Get-ADLCSid $user
    description                        = Get-ADLCString $user 'description'
    display_name                       = Get-ADLCString $user 'displayName'
    given_name                         = Get-ADLCString $user 'givenName'
    surname                            = Get-ADLCString $user 'sn'
    initials                           = Get-ADLCString $user 'initials'
    other_name                         = Get-ADLCString $user 'middleName'
    email                              = Get-ADLCString $user 'mail'
    office                             = Get-ADLCString $user 'physicalDeliveryOfficeName'
    office_phone                       = Get-ADLCString $user 'telephoneNumber'
    home_phone                         = Get-ADLCString $user 'homePhone'
    mobile_phone                       = Get-ADLCString $user 'mobile'
    fax                                = Get-ADLCString $user 'facsimileTelephoneNumber'
    home_page                          = Get-ADLCString $user 'wWWHomePage'
    street_address                     = Get-ADLCString $user 'streetAddress'
    po_box                             = Get-ADLCString $user 'postOfficeBox'
    city                               = Get-ADLCString $user 'l'
    state                              = Get-ADLCString $user 'st'
    postal_code                        = Get-ADLCString $user 'postalCode'
    country                            = Get-ADLCString $user 'c'
    company                            = Get-ADLCString $user 'company'
    department                         = Get-ADLCString $user 'department'
    division                           = Get-ADLCString $user 'division'
    organization                       = Get-ADLCString $user 'o'
    employee_id                        = Get-ADLCString $user 'employeeID'
    employee_number                    = Get-ADLCString $user 'employeeNumber'
    title                              = Get-ADLCString $user 'title'
    home_directory                     = Get-ADLCString $user 'homeDirectory'
    home_drive                         = Get-ADLCString $user 'homeDrive'
    logon_workstations                 = Get-ADLCString $user 'userWorkstations'
    script_path                        = Get-ADLCString $user 'scriptPath'
    profile_path                       = Get-ADLCString $user 'profilePath'
    account_expiration_date            = $accountExpirationDate
    manager                            = [string]$managerDN
    manager_match                      = $managerMatch
    enabled                            = $enabled
    password_never_expires             = $passwordNeverExpires
    cannot_change_password             = $cannotChangePassword
    smart_card_logon_required          = $smartCardRequired
    trusted_for_delegation             = $trustedForDelegation
    protected_from_accidental_deletion = $protected
} | ConvertTo-Json -Compress
