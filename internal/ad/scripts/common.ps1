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

function Convert-PathToDN([string]$Path, [string]$DomainDN) {
    # A path already containing the domain DN is treated as a literal container DN,
    # which allows containers such as CN=Users that are not organizational units.
    if ($Path -match [regex]::Escape($DomainDN) + '$') {
        return $Path
    }

    $segments = @($Path -split '/' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ($segments.Count -eq 0) {
        return $DomainDN
    }

    [array]::Reverse($segments)
    $ouParts = $segments | ForEach-Object { 'OU=' + $_ }
    return ($ouParts -join ',') + ',' + $DomainDN
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
