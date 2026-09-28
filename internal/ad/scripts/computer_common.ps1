# Computer account helpers. Requires common.ps1.

$script:ComputerProperties = @(
    'Description', 'DisplayName', 'DNSHostName', 'Enabled', 'Location', 'ManagedBy',
    'UserPrincipalName', 'KerberosEncryptionType', 'ServicePrincipalNames',
    'TrustedForDelegation', 'AccountNotDelegated', 'CompoundIdentitySupported',
    'OperatingSystem', 'OperatingSystemVersion', 'ProtectedFromAccidentalDeletion',
    'DistinguishedName', 'Name', 'SamAccountName', 'ObjectGUID', 'SID'
)

function Get-ComputerByIdentity([string]$Identity) {
    $serverParams = Get-ServerParams
    return Get-ADComputer -Identity $Identity -Properties $script:ComputerProperties @serverParams -ErrorAction Stop
}

function Get-ComputerOrNull([string]$Identity) {
    try {
        return Get-ComputerByIdentity $Identity
    }
    catch {
        if (Test-IsIdentityNotFound $_) {
            return $null
        }

        throw
    }
}

# Builds the Set-ADComputer parameter table for the scalar attributes that bind identically on
# New-ADComputer and Set-ADComputer. Identity (name/sam/path) and the multi-valued service
# principal names are handled separately, because they bind differently on the two cmdlets.
function Get-ComputerSetParams {
    $managedBy = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$payload.managed_by)) {
        $managedBy = (Resolve-ADPrincipal ([string]$payload.managed_by)).distinguishedName
    }

    $params = @{
        Description               = (Get-OptionalString $payload.description)
        DisplayName               = (Get-OptionalString $payload.display_name)
        DNSHostName               = (Get-OptionalString $payload.dns_host_name)
        Location                  = (Get-OptionalString $payload.location)
        UserPrincipalName         = (Get-OptionalString $payload.user_principal_name)
        ManagedBy                 = $managedBy
        Enabled                   = [bool]$payload.enabled
        TrustedForDelegation      = [bool]$payload.trusted_for_delegation
        AccountNotDelegated       = [bool]$payload.account_not_delegated
        CompoundIdentitySupported = [bool]$payload.compound_identity_supported
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

# Reconciles the service principal names authoritatively on an existing account. On
# Set-ADComputer these bind through a hashtable, and an empty set clears the attribute.
function Set-ComputerMultiValued([string]$DistinguishedName) {
    $serverParams = Get-ServerParams

    $spns = @()
    if ($null -ne $payload.service_principal_names) {
        $spns = @($payload.service_principal_names)
    }
    if ($spns.Count -eq 0) {
        Set-ADComputer -Identity $DistinguishedName -ServicePrincipalNames $null @serverParams -ErrorAction Stop
    }
    else {
        Set-ADComputer -Identity $DistinguishedName -ServicePrincipalNames @{ Replace = $spns } @serverParams -ErrorAction Stop
    }
}

# Not a Set-ADComputer parameter: adds or removes Deny ACEs for Everyone on Delete/DeleteTree.
function Sync-ComputerProtection([string]$DistinguishedName, [bool]$CurrentValue) {
    $serverParams = Get-ServerParams
    $desired = $false
    if ($null -ne $payload.protected_from_accidental_deletion) {
        $desired = [bool]$payload.protected_from_accidental_deletion
    }

    if ($CurrentValue -ne $desired) {
        Set-ADObject -Identity $DistinguishedName -ProtectedFromAccidentalDeletion $desired @serverParams -ErrorAction Stop
    }
}

function Get-ComputerResult($Computer, [string]$DomainDN) {
    $containerDN = Get-ParentDN $Computer.DistinguishedName

    $pathMatch = $false
    if ($null -ne $payload.path) {
        $pathMatch = ((Convert-PathToDN ([string]$payload.path) $DomainDN) -eq $containerDN)
    }

    $actualSam = [string]$Computer.SamAccountName
    $strippedSam = Get-StrippedSam $actualSam
    $samMatch = $false
    if (-not [string]::IsNullOrWhiteSpace([string]$payload.sam_account_name)) {
        $samMatch = ((Get-StrippedSam ([string]$payload.sam_account_name)) -ieq $strippedSam)
    }

    $managedByDN = [string]$Computer.ManagedBy
    $managedByMatch = $false
    if (-not [string]::IsNullOrWhiteSpace([string]$payload.managed_by)) {
        try {
            $managedByMatch = ((Resolve-ADPrincipal ([string]$payload.managed_by)).distinguishedName -eq $managedByDN)
        }
        catch {
            $managedByMatch = $false
        }
    }

    $spns = New-Object System.Collections.Generic.List[string]
    if ($null -ne $Computer.ServicePrincipalNames) {
        foreach ($spn in @($Computer.ServicePrincipalNames)) {
            $spns.Add([string]$spn)
        }
    }

    return [pscustomobject]@{
        exists                             = $true
        name                               = $Computer.Name
        sam_account_name                   = $actualSam
        sam_account_name_stripped          = $strippedSam
        sam_match                          = $samMatch
        dns_host_name                      = $Computer.DNSHostName
        path                               = Convert-DNToPath $containerDN $DomainDN
        path_match                         = $pathMatch
        container_dn                       = $containerDN
        distinguished_name                 = $Computer.DistinguishedName
        guid                               = [string]$Computer.ObjectGUID
        sid                                = [string]$Computer.SID
        description                        = $Computer.Description
        display_name                       = $Computer.DisplayName
        location                           = $Computer.Location
        user_principal_name                = $Computer.UserPrincipalName
        managed_by                         = $managedByDN
        managed_by_match                   = $managedByMatch
        enabled                            = [bool]$Computer.Enabled
        kerberos_encryption_type           = @(Convert-EncryptionTypesToTokens $Computer.KerberosEncryptionType)
        service_principal_names            = @($spns)
        trusted_for_delegation             = [bool]$Computer.TrustedForDelegation
        account_not_delegated              = [bool]$Computer.AccountNotDelegated
        compound_identity_supported        = [bool]$Computer.CompoundIdentitySupported
        operating_system                   = $Computer.OperatingSystem
        operating_system_version           = $Computer.OperatingSystemVersion
        protected_from_accidental_deletion = [bool]$Computer.ProtectedFromAccidentalDeletion
    }
}
