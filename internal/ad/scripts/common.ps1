# Helpers shared by every AD object type. Prefixed ahead of each operation script.
$ErrorActionPreference = 'Stop'

# Keep ANSI escapes out of stderr so provider diagnostics stay readable.
if ($null -ne $PSStyle) {
    $PSStyle.OutputRendering = 'PlainText'
}

Import-Module ActiveDirectory -ErrorAction Stop

function Get-ServerParams {
    $serverParams = @{}
    if ($null -ne $payload.domain_controller -and -not [string]::IsNullOrWhiteSpace([string]$payload.domain_controller)) {
        $serverParams['Server'] = [string]$payload.domain_controller
    }
    return $serverParams
}

function Get-DomainDN {
    $serverParams = Get-ServerParams
    return (Get-ADDomain @serverParams -ErrorAction Stop).DistinguishedName
}

# Accepts a slash-delimited OU path relative to the domain root, a distinguished name
# relative to the domain root, or a full distinguished name. Slash segments default to
# OU= but may carry their own RDN prefix. Slash segments are always OUs; a segment that
# matches the domain name is still an OU name, not a domain component.
function Convert-PathToDN([string]$Path, [string]$DomainDN) {
    $trimmed = ([string]$Path).Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $DomainDN
    }

    if ($trimmed -match ([regex]::Escape($DomainDN) + '\s*$')) {
        return $trimmed
    }

    if ($trimmed -match '^\s*DC=') {
        return $trimmed
    }

    # A relative DN such as 'CN=Computers' or 'CN=Services,CN=Configuration'.
    if (($trimmed -notmatch '/') -and ($trimmed -match '^[A-Za-z]+=')) {
        return $trimmed.TrimEnd(',') + ',' + $DomainDN
    }

    $segments = @($trimmed -split '/' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ($segments.Count -eq 0) {
        return $DomainDN
    }

    [array]::Reverse($segments)
    $parts = $segments | ForEach-Object {
        if ($_ -match '^[A-Za-z]+=') { $_ } else { 'OU=' + $_ }
    }

    return ($parts -join ',') + ',' + $DomainDN
}

function Convert-DNToPath([string]$DistinguishedName, [string]$DomainDN) {
    $relativeDN = $DistinguishedName
    if ($relativeDN.EndsWith(',' + $DomainDN)) {
        $relativeDN = $relativeDN.Substring(0, $relativeDN.Length - ($DomainDN.Length + 1))
    }

    $segments = @($relativeDN -split ',' | ForEach-Object {
        if ($_.StartsWith('OU=')) {
            $_.Substring(3)
        }
        else {
            $_
        }
    })

    [array]::Reverse($segments)
    return ($segments -join '/')
}

function Get-ParentDN([string]$DistinguishedName) {
    $parts = $DistinguishedName -split '(?<!\\),'
    return ($parts[1..($parts.Count - 1)] -join ',')
}

function Test-IsIdentityNotFound([System.Management.Automation.ErrorRecord]$ErrorRecord) {
    if ($null -eq $ErrorRecord) {
        return $false
    }

    if ($ErrorRecord.CategoryInfo.Reason -eq 'ADIdentityNotFoundException') {
        return $true
    }

    if ($null -ne $ErrorRecord.Exception -and $ErrorRecord.Exception.Message -match 'Cannot find an object with identity') {
        return $true
    }

    return $false
}

function Test-IsIdentityAlreadyExists([System.Management.Automation.ErrorRecord]$ErrorRecord) {
    if ($null -eq $ErrorRecord) {
        return $false
    }

    if ($ErrorRecord.CategoryInfo.Reason -eq 'ADIdentityAlreadyExistsException') {
        return $true
    }

    if ($null -ne $ErrorRecord.Exception -and $ErrorRecord.Exception.Message -match 'already exists') {
        return $true
    }

    return $false
}

function ConvertTo-LDAPFilterValue([string]$Value) {
    # RFC 4515 escaping: these characters are otherwise filter syntax.
    $builder = New-Object System.Text.StringBuilder
    foreach ($char in $Value.ToCharArray()) {
        switch ($char) {
            '\' { [void]$builder.Append('\5c') }
            '*' { [void]$builder.Append('\2a') }
            '(' { [void]$builder.Append('\28') }
            ')' { [void]$builder.Append('\29') }
            "`0" { [void]$builder.Append('\00') }
            default { [void]$builder.Append($char) }
        }
    }

    return $builder.ToString()
}

# Resolves a distinguished name, GUID, SID, DOMAIN\name or sAMAccountName to a
# directory object carrying the identifiers the provider stores in state.
function Resolve-ADPrincipal([string]$Identity) {
    $serverParams = Get-ServerParams
    $properties = @('objectSid', 'objectGUID', 'distinguishedName', 'sAMAccountName', 'objectClass')

    $parsedGuid = [guid]::Empty
    if (($Identity -match '^(CN|OU|DC)=') -or [guid]::TryParse($Identity, [ref]$parsedGuid)) {
        return Get-ADObject -Identity $Identity -Properties $properties @serverParams -ErrorAction Stop
    }

    if ($Identity -match '^S-\d-') {
        $escapedSid = ConvertTo-LDAPFilterValue $Identity
        $bySid = @(Get-ADObject -LDAPFilter "(objectSid=$escapedSid)" -Properties $properties @serverParams -ErrorAction Stop)
        if ($bySid.Count -gt 0) {
            return $bySid[0]
        }

        throw "no directory object has SID '$Identity'"
    }

    $samAccountName = $Identity
    if ($samAccountName.Contains('\')) {
        $samAccountName = $samAccountName.Split('\')[-1]
    }

    $escaped = ConvertTo-LDAPFilterValue $samAccountName
    $byName = @(Get-ADObject -LDAPFilter "(sAMAccountName=$escaped)" -Properties $properties @serverParams -ErrorAction Stop)
    if ($byName.Count -gt 0) {
        return $byName[0]
    }

    throw "no directory object found for identity '$Identity'"
}

# Security descriptors are read and written through the AD: drive.
function Get-ADObjectAclPath([string]$DistinguishedName) {
    if ($null -eq (Get-PSDrive -Name 'AD' -ErrorAction SilentlyContinue)) {
        New-PSDrive -Name 'AD' -PSProvider 'ActiveDirectory' -Root '//RootDSE/' -ErrorAction Stop | Out-Null
    }

    # Pin the drive to the configured DC so ACL reads and writes hit the same replica.
    if ($null -ne $payload.domain_controller -and -not [string]::IsNullOrWhiteSpace([string]$payload.domain_controller)) {
        (Get-PSDrive -Name 'AD' -ErrorAction Stop).Server = [string]$payload.domain_controller
    }

    return "AD:\$DistinguishedName"
}

# adminCount is not a default property, so it must always be requested explicitly.
function Get-AdminCount([string]$DistinguishedName) {
    $serverParams = Get-ServerParams
    $object = Get-ADObject -Identity $DistinguishedName -Properties adminCount @serverParams -ErrorAction Stop

    if ($null -eq $object.adminCount) {
        return 0
    }

    return [int]$object.adminCount
}

# pwdLastSet is a raw FILETIME (100-ns intervals since 1601), not a DateTime, and is 0
# when no password has ever been set. Returned as an ISO 8601 string, or $null, so callers
# can detect a password changing (by anyone, anywhere) without ever seeing the password
# itself.
function Get-PasswordLastSet([string]$DistinguishedName) {
    $serverParams = Get-ServerParams
    $object = Get-ADObject -Identity $DistinguishedName -Properties pwdLastSet @serverParams -ErrorAction Stop

    $raw = [int64]$object.pwdLastSet
    if ($raw -le 0) {
        return $null
    }

    return [DateTime]::FromFileTimeUtc($raw).ToString('o')
}

# Objects protected by AdminSDHolder (adminCount = 1) have their ACL reset to match
# AdminSDHolder's on the next SDProp run, typically within an hour. Any explicit ACE this
# provider adds would silently disappear, so refuse unless the caller opts in.
function Assert-NotAdminCountProtected([string]$DistinguishedName, [bool]$IgnoreAdminCount1) {
    if ($IgnoreAdminCount1) {
        return
    }

    if ((Get-AdminCount $DistinguishedName) -ne 1) {
        return
    }

    throw "'$DistinguishedName' has adminCount=1 (protected by AdminSDHolder). Its ACL is periodically " +
        "reset by SDProp to match AdminSDHolder, so any ACE added here will be silently reverted. " +
        "Set ignore_admin_count_1 = true to proceed anyway."
}

# ---------------------------------------------------------------------------
# Event logging
#
# Every operation that changes AD, and every operation that fails, records an entry in a
# classic Windows event log named 'terraform-provider-adlc' on the target host. Each
# operation script logs under its own source (the script file name without the .ps1
# extension) so entries can be filtered per operation. The log and each source are created
# on demand. The *-EventLog cmdlets were removed from PowerShell 7, so the .NET
# System.Diagnostics.EventLog API is used directly.
# ---------------------------------------------------------------------------

$script:ADLCEventLogName = 'terraform-provider-adlc'

# Key names whose values must never be written to the event log in cleartext.
$script:ADLCSensitiveKeyPattern = 'password|passphrase|secret|credential|private_key|pfx|token'

# Ensures the classic event log and the given source both exist. CreateEventSource creates
# the log too when it is missing. Requires administrator rights on the target host and is a
# no-op once the source is registered.
function Register-ADLCEventSource([string]$Source) {
    if ([string]::IsNullOrWhiteSpace($Source)) {
        return
    }

    if ([System.Diagnostics.EventLog]::SourceExists($Source)) {
        return
    }

    [System.Diagnostics.EventLog]::CreateEventSource($Source, $script:ADLCEventLogName)
}

# Writes one entry to the provider event log, registering the source on first use. Logging
# must never mask the operation it describes, so permission or registration failures are
# swallowed.
function Write-ADLCEvent {
    param(
        [string]$Source,
        [System.Diagnostics.EventLogEntryType]$EntryType = [System.Diagnostics.EventLogEntryType]::Information,
        [string]$Message,
        [int]$EventId = 1000
    )

    if ([string]::IsNullOrWhiteSpace($Source)) {
        return
    }

    try {
        Register-ADLCEventSource $Source
        [System.Diagnostics.EventLog]::WriteEntry($Source, $Message, $EntryType, $EventId)
    }
    catch {
        # Best effort only: never let an event-log failure break the AD operation.
    }
}

# Renders $payload as JSON for inclusion in log entries, masking values whose key names
# look like secrets so passwords never reach the event log in cleartext.
function Get-ADLCInputText {
    if ($null -eq $payload) {
        return '<no input>'
    }

    try {
        $redacted = [ordered]@{}
        foreach ($property in $payload.PSObject.Properties) {
            if ($property.Name -match $script:ADLCSensitiveKeyPattern) {
                $redacted[$property.Name] = '***redacted***'
            }
            else {
                $redacted[$property.Name] = $property.Value
            }
        }

        return ([pscustomobject]$redacted | ConvertTo-Json -Depth 10 -Compress)
    }
    catch {
        return '<input could not be serialized>'
    }
}

# Logs a completed change together with the script input. Called automatically after a
# mutating operation body succeeds.
function Write-ADLCChange([string]$Source, [string]$Message) {
    $entry = "$Message`nInput: $(Get-ADLCInputText)"
    Write-ADLCEvent -Source $Source -EntryType ([System.Diagnostics.EventLogEntryType]::Information) -Message $entry -EventId 1000
}

# Logs a failed operation with the script input and the error message. Called automatically
# when an operation body throws.
function Write-ADLCFailure([string]$Source, [System.Management.Automation.ErrorRecord]$ErrorRecord) {
    $errorText = '<unknown error>'
    if ($null -ne $ErrorRecord) {
        $errorText = [string]$ErrorRecord.Exception.Message
        if (-not [string]::IsNullOrWhiteSpace([string]$ErrorRecord.ScriptStackTrace)) {
            $errorText += "`n" + [string]$ErrorRecord.ScriptStackTrace
        }
    }

    $entry = "Operation '$Source' failed.`nInput: $(Get-ADLCInputText)`nError: $errorText"
    Write-ADLCEvent -Source $Source -EntryType ([System.Diagnostics.EventLogEntryType]::Error) -Message $entry -EventId 1001
}
