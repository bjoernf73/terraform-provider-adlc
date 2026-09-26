# Group managed service account (gMSA) helpers. Requires common.ps1.

$script:GmsaProperties = @(
    'Description', 'DisplayName', 'DNSHostName', 'Enabled', 'HomePage',
    'KerberosEncryptionType', 'ManagedPasswordIntervalInDays',
    'PrincipalsAllowedToRetrieveManagedPassword', 'PrincipalsAllowedToDelegateToAccount',
    'ServicePrincipalNames', 'TrustedForDelegation', 'AccountNotDelegated',
    'CompoundIdentitySupported', 'AccountExpirationDate', 'ProtectedFromAccidentalDeletion',
    'DistinguishedName', 'Name', 'SamAccountName', 'ObjectGUID', 'SID', 'msDS-ManagedPasswordInterval'
)

function Get-GmsaByIdentity([string]$Identity) {
    $serverParams = Get-ServerParams
    return Get-ADServiceAccount -Identity $Identity -Properties $script:GmsaProperties @serverParams -ErrorAction Stop
}

function Get-GmsaOrNull([string]$Identity) {
    try {
        return Get-GmsaByIdentity $Identity
    }
    catch {
        if (Test-IsIdentityNotFound $_) {
            return $null
        }

        throw
    }
}

# A gMSA sAMAccountName always ends with '$'. Users may configure the account name with or
# without it; strip a single trailing '$' so both spellings resolve to the same account.
function Get-StrippedSam([string]$Value) {
    $trimmed = ([string]$Value).Trim()
    if ($trimmed.EndsWith('$')) {
        return $trimmed.Substring(0, $trimmed.Length - 1)
    }

    return $trimmed
}

# msDS-SupportedEncryptionTypes is a bit flag. Map it to the token set Set-ADServiceAccount
# accepts so state carries a stable, human-readable value.
function Convert-EncryptionTypesToTokens($Value) {
    $bits = 0
    if ($null -ne $Value) {
        $bits = [int]$Value
    }

    if ($bits -eq 0) {
        return , @('None')
    }

    $tokens = New-Object System.Collections.Generic.List[string]
    if ($bits -band 0x3) { $tokens.Add('DES') }   # DES-CBC-CRC (0x1) or DES-CBC-MD5 (0x2)
    if ($bits -band 0x4) { $tokens.Add('RC4') }
    if ($bits -band 0x8) { $tokens.Add('AES128') }
    if ($bits -band 0x10) { $tokens.Add('AES256') }

    return , @($tokens)
}

# Resolves an array of principal identities to their distinguished names, preserving order
# and dropping duplicates.
function Resolve-PrincipalDNs($Identities) {
    $result = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Identities) {
        return , @($result)
    }

    foreach ($identity in @($Identities)) {
        if ([string]::IsNullOrWhiteSpace([string]$identity)) {
            continue
        }

        $dn = (Resolve-ADPrincipal ([string]$identity)).distinguishedName
        if (-not $result.Contains($dn)) {
            $result.Add($dn)
        }
    }

    return , @($result)
}

# Reads the distinguished names currently assigned to a multi-valued principal attribute.
function Get-AssignedPrincipalDNs($Values) {
    $result = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Values) {
        return , @($result)
    }

    foreach ($value in @($Values)) {
        $result.Add([string]$value)
    }

    return , @($result)
}

# True when two DN lists hold the same members regardless of order.
function Test-DNSetsEqual($Left, $Right) {
    $leftSet = @($Left)
    $rightSet = @($Right)
    if ($leftSet.Count -ne $rightSet.Count) {
        return $false
    }

    $normalizedLeft = $leftSet | ForEach-Object { ([string]$_).ToLowerInvariant() } | Sort-Object
    $normalizedRight = $rightSet | ForEach-Object { ([string]$_).ToLowerInvariant() } | Sort-Object
    for ($i = 0; $i -lt $normalizedLeft.Count; $i++) {
        if ($normalizedLeft[$i] -ne $normalizedRight[$i]) {
            return $false
        }
    }

    return $true
}

# Builds the Set-ADServiceAccount parameter table for the scalar attributes that bind
# identically on New-ADServiceAccount and Set-ADServiceAccount. Identity (name/sam/path) and
# the multi-valued attributes are handled separately, because the latter bind differently on
# the two cmdlets.
function Get-GmsaSetParams {
    $accountExpirationDate = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$payload.account_expiration_date)) {
        $accountExpirationDate = [datetime]::Parse([string]$payload.account_expiration_date, [System.Globalization.CultureInfo]::InvariantCulture)
    }

    $params = @{
        DNSHostName               = [string]$payload.dns_host_name
        Description               = (Get-OptionalString $payload.description)
        DisplayName               = (Get-OptionalString $payload.display_name)
        HomePage                  = (Get-OptionalString $payload.home_page)
        Enabled                   = [bool]$payload.enabled
        TrustedForDelegation      = [bool]$payload.trusted_for_delegation
        AccountNotDelegated       = [bool]$payload.account_not_delegated
        CompoundIdentitySupported = [bool]$payload.compound_identity_supported
        AccountExpirationDate     = $accountExpirationDate
    }

    # KerberosEncryptionType is Optional+Computed: only reconcile it when configured. It is a
    # single flags enum, so the tokens are joined into one comma-separated value.
    if ($null -ne $payload.kerberos_encryption_type) {
        $tokens = @($payload.kerberos_encryption_type)
        if ($tokens.Count -eq 0) {
            $params.KerberosEncryptionType = 'None'
        }
        else {
            $params.KerberosEncryptionType = ($tokens -join ',')
        }
    }

    return $params
}

# Reconciles the multi-valued attributes authoritatively on an existing account. These bind
# differently from New-ADServiceAccount: service principal names take a hashtable, and an
# empty set clears the attribute rather than replacing it with a value.
function Set-GmsaMultiValued([string]$DistinguishedName) {
    $serverParams = Get-ServerParams

    $spns = @()
    if ($null -ne $payload.service_principal_names) {
        $spns = @($payload.service_principal_names)
    }
    if ($spns.Count -eq 0) {
        Set-ADServiceAccount -Identity $DistinguishedName -ServicePrincipalNames $null @serverParams -ErrorAction Stop
    }
    else {
        Set-ADServiceAccount -Identity $DistinguishedName -ServicePrincipalNames @{ Replace = $spns } @serverParams -ErrorAction Stop
    }

    $retrieve = @(Resolve-PrincipalDNs $payload.principals_allowed_to_retrieve_managed_password)
    if ($retrieve.Count -eq 0) {
        Set-ADServiceAccount -Identity $DistinguishedName -PrincipalsAllowedToRetrieveManagedPassword $null @serverParams -ErrorAction Stop
    }
    else {
        Set-ADServiceAccount -Identity $DistinguishedName -PrincipalsAllowedToRetrieveManagedPassword $retrieve @serverParams -ErrorAction Stop
    }

    $delegate = @(Resolve-PrincipalDNs $payload.principals_allowed_to_delegate_to_account)
    if ($delegate.Count -eq 0) {
        Set-ADServiceAccount -Identity $DistinguishedName -PrincipalsAllowedToDelegateToAccount $null @serverParams -ErrorAction Stop
    }
    else {
        Set-ADServiceAccount -Identity $DistinguishedName -PrincipalsAllowedToDelegateToAccount $delegate @serverParams -ErrorAction Stop
    }
}

# Not a Set-ADServiceAccount parameter: adds or removes Deny ACEs for Everyone on
# Delete/DeleteTree.
function Sync-GmsaProtection([string]$DistinguishedName, [bool]$CurrentValue) {
    $serverParams = Get-ServerParams
    $desired = $false
    if ($null -ne $payload.protected_from_accidental_deletion) {
        $desired = [bool]$payload.protected_from_accidental_deletion
    }

    if ($CurrentValue -ne $desired) {
        Set-ADObject -Identity $DistinguishedName -ProtectedFromAccidentalDeletion $desired @serverParams -ErrorAction Stop
    }
}

function Get-GmsaResult($Gmsa, [string]$DomainDN) {
    $containerDN = Get-ParentDN $Gmsa.DistinguishedName

    $pathMatch = $false
    if ($null -ne $payload.path) {
        $pathMatch = ((Convert-PathToDN ([string]$payload.path) $DomainDN) -eq $containerDN)
    }

    $actualSam = [string]$Gmsa.SamAccountName
    $strippedSam = Get-StrippedSam $actualSam
    $samMatch = $false
    if (-not [string]::IsNullOrWhiteSpace([string]$payload.sam_account_name)) {
        $samMatch = ((Get-StrippedSam ([string]$payload.sam_account_name)) -ieq $strippedSam)
    }

    $retrieveDNs = Get-AssignedPrincipalDNs $Gmsa.PrincipalsAllowedToRetrieveManagedPassword
    $retrieveMatch = Test-DNSetsEqual $retrieveDNs (Resolve-PrincipalDNs $payload.principals_allowed_to_retrieve_managed_password)

    $delegateDNs = Get-AssignedPrincipalDNs $Gmsa.PrincipalsAllowedToDelegateToAccount
    $delegateMatch = Test-DNSetsEqual $delegateDNs (Resolve-PrincipalDNs $payload.principals_allowed_to_delegate_to_account)

    $spns = New-Object System.Collections.Generic.List[string]
    if ($null -ne $Gmsa.ServicePrincipalNames) {
        foreach ($spn in @($Gmsa.ServicePrincipalNames)) {
            $spns.Add([string]$spn)
        }
    }

    # ManagedPasswordIntervalInDays is not read back by that name; it lives on
    # msDS-ManagedPasswordInterval and is fixed at creation.
    $interval = 0
    if ($null -ne $Gmsa.'msDS-ManagedPasswordInterval') {
        $interval = [int]$Gmsa.'msDS-ManagedPasswordInterval'
    }

    return [pscustomobject]@{
        exists                                              = $true
        name                                                = $Gmsa.Name
        sam_account_name                                    = $actualSam
        sam_account_name_stripped                           = $strippedSam
        sam_match                                           = $samMatch
        dns_host_name                                       = $Gmsa.DNSHostName
        path                                                = Convert-DNToPath $containerDN $DomainDN
        path_match                                          = $pathMatch
        container_dn                                        = $containerDN
        distinguished_name                                  = $Gmsa.DistinguishedName
        guid                                                = [string]$Gmsa.ObjectGUID
        sid                                                 = [string]$Gmsa.SID
        description                                         = $Gmsa.Description
        display_name                                        = $Gmsa.DisplayName
        home_page                                           = $Gmsa.HomePage
        enabled                                             = [bool]$Gmsa.Enabled
        kerberos_encryption_type                            = @(Convert-EncryptionTypesToTokens $Gmsa.KerberosEncryptionType)
        managed_password_interval_days                      = $interval
        principals_allowed_to_retrieve_managed_password     = @($retrieveDNs)
        principals_allowed_to_retrieve_managed_password_match = $retrieveMatch
        principals_allowed_to_delegate_to_account           = @($delegateDNs)
        principals_allowed_to_delegate_to_account_match     = $delegateMatch
        service_principal_names                             = @($spns)
        trusted_for_delegation                              = [bool]$Gmsa.TrustedForDelegation
        account_not_delegated                               = [bool]$Gmsa.AccountNotDelegated
        compound_identity_supported                         = [bool]$Gmsa.CompoundIdentitySupported
        account_expiration_date                             = if ($null -ne $Gmsa.AccountExpirationDate) { $Gmsa.AccountExpirationDate.ToString('yyyy-MM-dd') } else { $null }
        protected_from_accidental_deletion                  = [bool]$Gmsa.ProtectedFromAccidentalDeletion
    }
}
