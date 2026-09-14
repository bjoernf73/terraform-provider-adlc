# Access rule helpers. Requires common.ps1.

function Resolve-TrusteeSid([string]$Trustee) {
    if ($Trustee -match '^S-\d-') {
        return $Trustee
    }

    try {
        $principal = Resolve-ADPrincipal $Trustee
        if ($null -ne $principal.objectSid) {
            return $principal.objectSid.Value
        }
    }
    catch {
        # Falls through to the well-known principal lookup below.
    }

    # Well-known principals such as 'Authenticated Users' are not directory objects.
    return ([System.Security.Principal.NTAccount]$Trustee).Translate([System.Security.Principal.SecurityIdentifier]).Value
}

# Resolves a schema class, attribute, property set or extended right to its GUID.
# Targeted lookups only; enumerating the whole schema per call is far too slow.
function Resolve-ADGuid([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $null
    }

    if ($Name -eq 'All') {
        return [guid]::Empty
    }

    $parsed = [guid]::Empty
    if ([guid]::TryParse($Name, [ref]$parsed)) {
        return $parsed
    }

    $serverParams = Get-ServerParams
    $rootDSE = Get-ADRootDSE @serverParams -ErrorAction Stop
    $escaped = ConvertTo-LDAPFilterValue $Name

    $schema = @(Get-ADObject -SearchBase $rootDSE.SchemaNamingContext -LDAPFilter "(lDAPDisplayName=$escaped)" -Properties schemaIDGUID @serverParams -ErrorAction Stop)
    if ($schema.Count -gt 0) {
        return [guid]$schema[0].schemaIDGUID
    }

    $right = @(Get-ADObject -SearchBase $rootDSE.ConfigurationNamingContext -LDAPFilter "(&(objectClass=controlAccessRight)(displayName=$escaped))" -Properties rightsGuid @serverParams -ErrorAction Stop)
    if ($right.Count -gt 0) {
        return [guid]$right[0].rightsGuid
    }

    throw "unknown object type '$Name'; expected a schema class, attribute, property set, extended right or GUID"
}

function Get-AccessRuleContext {
    $inheritance = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$payload.inheritance)) {
        $inheritance = [System.DirectoryServices.ActiveDirectorySecurityInheritance][string]$payload.inheritance
    }

    return [pscustomobject]@{
        TargetDN                = Convert-PathToDN ([string]$payload.target) (Get-DomainDN)
        Sid                     = Resolve-TrusteeSid ([string]$payload.trustee)
        Access                  = [string]$payload.access
        ObjectTypeGuid          = Resolve-ADGuid ([string]$payload.object_type)
        InheritedObjectTypeGuid = Resolve-ADGuid ([string]$payload.inherited_object_type)
        Inheritance             = $inheritance
        Rights                  = @($payload.rights | ForEach-Object { [string]$_ })
    }
}

# Selects the ActiveDirectoryAccessRule constructor by argument list. The optional
# arguments must appear in this order: objectType, inheritance, inheritedObjectType,
# which yields each of the six documented overloads.
function New-ADAccessRule($Context) {
    $identity = [System.Security.Principal.IdentityReference]([System.Security.Principal.SecurityIdentifier]$Context.Sid)
    $rights = [System.DirectoryServices.ActiveDirectoryRights]($Context.Rights -join ', ')
    $accessType = [System.Security.AccessControl.AccessControlType]$Context.Access

    $arguments = @($identity, $rights, $accessType)
    if ($null -ne $Context.ObjectTypeGuid) {
        $arguments += , $Context.ObjectTypeGuid
    }
    if ($null -ne $Context.Inheritance) {
        $arguments += , $Context.Inheritance
    }
    if ($null -ne $Context.InheritedObjectTypeGuid) {
        $arguments += , $Context.InheritedObjectTypeGuid
    }

    if ($null -ne $Context.InheritedObjectTypeGuid -and $null -eq $Context.Inheritance) {
        throw 'inherited_object_type requires inheritance to be set'
    }

    return New-Object System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $arguments
}

# Identity of an ACE for this provider: everything except the rights themselves.

# .NET can return $null instead of Guid.Empty for ObjectType/InheritedObjectType on a
# plain ACE re-read from the server when an object ACE for the same trustee and flags
# also exists; the two are semantically identical, so treat them the same.
function Get-NormalizedGuid($Value) {
    if ($null -eq $Value) {
        return [guid]::Empty
    }

    return $Value
}

function Test-AccessRuleKey($Ace, $Context) {
    if ($Ace.IsInherited) {
        return $false
    }

    $aceSid = $Ace.IdentityReference
    if ($aceSid -isnot [System.Security.Principal.SecurityIdentifier]) {
        $aceSid = $aceSid.Translate([System.Security.Principal.SecurityIdentifier])
    }

    if ($aceSid.Value -ne $Context.Sid) {
        return $false
    }

    if ([string]$Ace.AccessControlType -ne $Context.Access) {
        return $false
    }

    $expectedObjectType = [guid]::Empty
    if ($null -ne $Context.ObjectTypeGuid) {
        $expectedObjectType = $Context.ObjectTypeGuid
    }
    if ((Get-NormalizedGuid $Ace.ObjectType) -ne $expectedObjectType) {
        return $false
    }

    $expectedInherited = [guid]::Empty
    if ($null -ne $Context.InheritedObjectTypeGuid) {
        $expectedInherited = $Context.InheritedObjectTypeGuid
    }
    if ((Get-NormalizedGuid $Ace.InheritedObjectType) -ne $expectedInherited) {
        return $false
    }

    # Unset inheritance means the constructor without an inheritance parameter, which
    # .NET defaults to None. Compare unconditionally, like ObjectType/InheritedObjectType
    # above, otherwise an unset inheritance would match an ACE with ANY inheritance.
    $expectedInheritance = 'None'
    if ($null -ne $Context.Inheritance) {
        $expectedInheritance = [string]$Context.Inheritance
    }
    if ([string]$Ace.InheritanceType -ne $expectedInheritance) {
        return $false
    }

    return $true
}

# A Get-Acl immediately following a Set-Acl on the same object can occasionally miss the
# just-written ACE; retry briefly rather than treating that race as "does not exist".
# Only used by the standalone Read path - Ensure builds its result from the rule it just
# wrote instead of reading it back, which avoids this race entirely.
function Find-AccessRuleAce($Context) {
    $aclPath = Get-ADObjectAclPath $Context.TargetDN
    $attempts = 4

    for ($attempt = 1; $attempt -le $attempts; $attempt++) {
        $acl = Get-Acl -Path $aclPath -ErrorAction Stop
        foreach ($ace in @($acl.Access)) {
            if (Test-AccessRuleKey $ace $Context) {
                return $ace
            }
        }

        if ($attempt -lt $attempts) {
            Start-Sleep -Seconds 2
        }
    }

    return $null
}

# TEMPORARY diagnostic: dumps every non-inherited ACE on the target so a failed match can
# be root-caused from CI logs instead of guessed at. Remove once the access rule matching
# bug is confirmed fixed.
function Get-AccessRuleDebugSnapshot($Context) {
    $aclPath = Get-ADObjectAclPath $Context.TargetDN
    $acl = Get-Acl -Path $aclPath -ErrorAction Stop

    $snapshot = @()
    foreach ($ace in @($acl.Access)) {
        if ($ace.IsInherited) {
            continue
        }

        $aceSid = $ace.IdentityReference
        if ($aceSid -isnot [System.Security.Principal.SecurityIdentifier]) {
            $aceSid = $aceSid.Translate([System.Security.Principal.SecurityIdentifier])
        }

        $objectTypeRaw = if ($null -eq $ace.ObjectType) { '<null>' } else { $ace.ObjectType.ToString() }
        $inheritedObjectTypeRaw = if ($null -eq $ace.InheritedObjectType) { '<null>' } else { $ace.InheritedObjectType.ToString() }

        $snapshot += "sid=$($aceSid.Value) type=$($ace.GetType().Name) access=$([string]$ace.AccessControlType) rights=$([int]$ace.ActiveDirectoryRights) objectType=$objectTypeRaw inheritedObjectType=$inheritedObjectTypeRaw inheritance=$([string]$ace.InheritanceType)"
    }

    return $snapshot
}

function Get-AccessRuleResult($Context, $Ace) {
    $actualMask = [int]$Ace.ActiveDirectoryRights
    $desiredMask = [int][System.DirectoryServices.ActiveDirectoryRights]($Context.Rights -join ', ')

    return [pscustomobject]@{
        exists                     = $true
        target_dn                  = $Context.TargetDN
        trustee_sid                = $Context.Sid
        access                     = [string]$Ace.AccessControlType
        rights                     = @($Ace.ActiveDirectoryRights.ToString() -split ',\s*')
        rights_mask                = $actualMask
        # Lets the provider keep the configured spelling when the effective mask is
        # unchanged; .NET renders some flag combinations under a composite name.
        rights_match               = ($actualMask -eq $desiredMask)
        object_type_guid           = [string](Get-NormalizedGuid $Ace.ObjectType)
        inherited_object_type_guid = [string](Get-NormalizedGuid $Ace.InheritedObjectType)
        inheritance                = [string]$Ace.InheritanceType
    }
}
