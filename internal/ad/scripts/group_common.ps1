# Group helpers. Requires common.ps1.

# Optional single-valued string attributes, mapped from payload key to LDAP attribute.
$script:GroupAttributeMap = @(
    @{ Key = 'description'; Attribute = 'description' }
    @{ Key = 'display_name'; Attribute = 'displayName' }
    @{ Key = 'mail'; Attribute = 'mail' }
    @{ Key = 'info'; Attribute = 'info' }
    @{ Key = 'homepage'; Attribute = 'wWWHomePage' }
)

function Get-GroupResult($Group, [string]$DomainDN) {
    $containerDN = Get-ParentDN $Group.DistinguishedName

    # Lets the provider keep the configured spelling of path when it resolves to the
    # same container; a DN and a slash path can denote the same place.
    $pathMatch = $false
    if ($null -ne $payload.path) {
        $pathMatch = ((Convert-PathToDN ([string]$payload.path) $DomainDN) -eq $containerDN)
    }

    # Same idea for managed_by, which may be configured as a name but stored as a DN.
    $managedByMatch = $false
    if (-not [string]::IsNullOrWhiteSpace([string]$payload.managed_by)) {
        try {
            $managedByMatch = ((Resolve-ADPrincipal ([string]$payload.managed_by)).distinguishedName -eq [string]$Group.ManagedBy)
        }
        catch {
            $managedByMatch = $false
        }
    }

    return [pscustomobject]@{
        exists                             = $true
        name                               = $Group.Name
        sam_account_name                   = $Group.SamAccountName
        description                        = $Group.Description
        display_name                       = $Group.DisplayName
        mail                               = $Group.mail
        info                               = $Group.info
        homepage                           = $Group.wWWHomePage
        managed_by                         = [string]$Group.ManagedBy
        managed_by_match                   = $managedByMatch
        protected_from_accidental_deletion = [bool]$Group.ProtectedFromAccidentalDeletion
        category                           = [string]$Group.GroupCategory
        scope                              = [string]$Group.GroupScope
        path                               = Convert-DNToPath $containerDN $DomainDN
        path_match                         = $pathMatch
        container_dn                       = $containerDN
        distinguished_name                 = $Group.DistinguishedName
        guid                               = [string]$Group.ObjectGUID
        sid                                = [string]$Group.SID
    }
}

function Get-GroupByIdentity([string]$Identity) {
    $serverParams = Get-ServerParams
    $properties = @(
        'Description', 'DisplayName', 'DistinguishedName', 'Name', 'SamAccountName',
        'GroupCategory', 'GroupScope', 'ObjectGUID', 'SID', 'ManagedBy', 'mail', 'info',
        'wWWHomePage', 'ProtectedFromAccidentalDeletion'
    )

    return Get-ADGroup -Identity $Identity -Properties $properties @serverParams -ErrorAction Stop
}

# Reconciles everything that can change in place. Shared by ensure and update so the
# two paths cannot drift apart.
function Sync-GroupProperties($Group) {
    $serverParams = Get-ServerParams
    $identity = $Group.DistinguishedName

    $setParams = @{}
    if ([string]$Group.SamAccountName -ne [string]$payload.sam_account_name) {
        $setParams['SamAccountName'] = [string]$payload.sam_account_name
    }
    if ([string]$Group.GroupCategory -ne [string]$payload.category) {
        $setParams['GroupCategory'] = [string]$payload.category
    }
    if ([string]$Group.GroupScope -ne [string]$payload.scope) {
        $setParams['GroupScope'] = [string]$payload.scope
    }
    if ($setParams.Count -gt 0) {
        Set-ADGroup -Identity $identity @setParams @serverParams -ErrorAction Stop
    }

    $replace = @{}
    $clear = @()

    foreach ($mapping in $script:GroupAttributeMap) {
        $desired = [string]$payload.($mapping.Key)
        $current = [string]$Group.($mapping.Attribute)

        if ([string]::IsNullOrWhiteSpace($desired)) {
            if (-not [string]::IsNullOrWhiteSpace($current)) {
                $clear += $mapping.Attribute
            }
        }
        elseif ($current -ne $desired) {
            $replace[$mapping.Attribute] = $desired
        }
    }

    $managedBy = [string]$payload.managed_by
    if ([string]::IsNullOrWhiteSpace($managedBy)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$Group.ManagedBy)) {
            $clear += 'managedBy'
        }
    }
    else {
        $managedByDN = (Resolve-ADPrincipal $managedBy).distinguishedName
        if ([string]$Group.ManagedBy -ne $managedByDN) {
            $replace['managedBy'] = $managedByDN
        }
    }

    if ($replace.Count -gt 0) {
        Set-ADGroup -Identity $identity -Replace $replace @serverParams -ErrorAction Stop
    }
    if ($clear.Count -gt 0) {
        Set-ADGroup -Identity $identity -Clear $clear @serverParams -ErrorAction Stop
    }

    # Not a stored attribute: this adds or removes Deny ACEs for Everyone on Delete
    # and DeleteTree.
    $protected = $false
    if ($null -ne $payload.protected_from_accidental_deletion) {
        $protected = [bool]$payload.protected_from_accidental_deletion
    }
    if ([bool]$Group.ProtectedFromAccidentalDeletion -ne $protected) {
        Set-ADObject -Identity $identity -ProtectedFromAccidentalDeletion $protected @serverParams -ErrorAction Stop
    }

    return Get-GroupByIdentity $identity
}

function Get-GroupOrNull([string]$Identity) {
    try {
        return Get-GroupByIdentity $Identity
    }
    catch {
        if (Test-IsIdentityNotFound $_) {
            return $null
        }

        throw
    }
}
