# Imports a JSON GPO (see internal/ad/json_gpo.go) into $payload.target_name, creating
# it if needed. Re-running this against an existing target overwrites its SYSVOL content
# in place (same GUID, links and ACLs kept), so it also serves as the update path.
#
# Known limitation: each section (registry, security template, audit, scripts, GPP) is
# only overwritten when present in the JSON; a section removed from the JSON since the
# last apply leaves its previously written file behind rather than deleting it.
Import-Module GroupPolicy -ErrorAction Stop

$jsonRaw = Resolve-JsonGPOReplacements ([string]$payload.json_raw) $payload.replacements
$imported = $jsonRaw | ConvertFrom-Json -ErrorAction Stop

$serverParams = Get-ServerParams
$targetName = [string]$payload.target_name

$gpo = $null
try {
    $gpo = Get-GPO -Name $targetName @serverParams -ErrorAction Stop
}
catch {
    if (-not (Test-IsGPONotFound $_)) {
        throw
    }
}

if ($null -eq $gpo) {
    $gpo = New-GPO -Name $targetName @serverParams -ErrorAction Stop
}

$policyGuid = "{$($gpo.Id.ToString())}"
$sysvolRoot = Get-JsonGPOSysvolPath -PolicyGuid $policyGuid

# GPO comment
if ($imported.PolicySettings.GPOComments) {
    if (-not (Test-JsonGPOCommentInSpec $imported.PolicySettings.GPOComments)) {
        throw 'GPO comment exceeds the 2047 character limit (a line break counts as 2)'
    }
    $imported.PolicySettings.GPOComments | Out-File -FilePath "$sysvolRoot\GPO.cmt" -Encoding unicode -Force
}

# Administrative template comments
if ($imported.PolicySettings.MachineComments) {
    New-Item -Path "$sysvolRoot\Machine" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    $imported.PolicySettings.MachineComments | Out-File -FilePath "$sysvolRoot\Machine\comment.cmtx" -Encoding utf8 -Force
}
if ($imported.PolicySettings.UserComments) {
    New-Item -Path "$sysvolRoot\User" -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    $imported.PolicySettings.UserComments | Out-File -FilePath "$sysvolRoot\User\comment.cmtx" -Encoding utf8 -Force
}

# Registry settings. $incrementBy tracks how much to bump versionNumber by below: +1 if
# any machine setting was written, +65536 if any user setting was written.
$allowedRegistryValueTypes = @('REG_SZ', 'REG_MULTI_SZ', 'REG_DWORD', 'REG_QWORD', 'REG_NONE')
[uint32]$incrementBy = 0
if ($imported.PolicySettings.RegistrySettings) {
    $byTarget = @{ Machine = @(); User = @() }

    foreach ($setting in $imported.PolicySettings.RegistrySettings) {
        $valueType = [string]$setting.ValueType
        if ($allowedRegistryValueTypes -notcontains $valueType) {
            Write-Warning "skipping registry setting with unsupported value type '$valueType' (key '$($setting.KeyName)')"
            continue
        }

        $target = [string]$setting.Target
        if ($target -ne 'Machine' -and $target -ne 'User') {
            throw "registry setting target must be 'Machine' or 'User', got '$target'"
        }

        # A lone null character represents the (Default) value in some exports; treat it
        # the same as an empty value name.
        $valueName = [string]$setting.ValueName
        if ($valueName.Length -eq 1 -and [byte][char]$valueName -eq 0) {
            $valueName = ''
        }

        $valueData = $setting.ValueData
        switch ($valueType) {
            'REG_DWORD' { $valueData = [uint32]$valueData }
            'REG_QWORD' { $valueData = [uint64]$valueData }
            default { $valueData = Resolve-JsonGPOToken ([string]$valueData) }
        }

        $entry = New-GPRegistryPolicy -keyName ([string]$setting.KeyName) -valueName $valueName -valueType $valueType -valueData $valueData
        $byTarget[$target] += $entry
    }

    foreach ($target in @('Machine', 'User')) {
        if ($byTarget[$target].Count -eq 0) {
            continue
        }

        $dir = "$sysvolRoot\$target"
        New-Item -Path $dir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
        $polPath = "$dir\Registry.pol"
        New-GPRegistryPolicyFile -Path $polPath
        Add-RegistryPolicies -Path $polPath -RegistryPolicies $byTarget[$target]

        if ($target -eq 'Machine') { $incrementBy += 1 } else { $incrementBy += 65536 }
    }
}

# Audit settings
if ($imported.PolicySettings.AuditSettings) {
    $auditDir = "$sysvolRoot\Machine\Microsoft\Windows NT\Audit"
    New-Item -Path $auditDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

    $csv = $imported.PolicySettings.AuditSettings |
        Select-Object -Property * -ExcludeProperty ObjectType |
        ConvertTo-Csv -NoTypeInformation -Delimiter ',' |
        ForEach-Object { $_.Replace('"', '') }
    $csv | Out-File -FilePath "$auditDir\audit.csv" -Encoding utf8 -Force
}

# Security template (GptTmpl.inf); tokens can appear mid-line, embedded in SDDL strings.
if ($imported.PolicySettings.SecurityTemplate) {
    $secDir = "$sysvolRoot\Machine\Microsoft\Windows NT\SecEdit"
    New-Item -Path $secDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

    $lines = @($imported.PolicySettings.SecurityTemplate | ForEach-Object { Resolve-JsonGPOToken ([string]$_) })
    $lines | Out-File -FilePath "$secDir\GptTmpl.inf" -Encoding default -Force
}

# Logon/logoff/startup/shutdown scripts
if ($imported.PolicySettings.Scripts) {
    foreach ($script in $imported.PolicySettings.Scripts) {
        $target = [string]$script.Target
        $scriptsDir = "$sysvolRoot\$target\Scripts"
        New-Item -Path $scriptsDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

        Write-JsonGPOIniFile -Path "$scriptsDir\scripts.ini" -Sections (ConvertTo-JsonGPOHashtable $script.ScriptsIni)
        Write-JsonGPOIniFile -Path "$scriptsDir\psscripts.ini" -Sections (ConvertTo-JsonGPOHashtable $script.PSScriptsIni)

        foreach ($file in @($script.ScriptFiles)) {
            if ($null -eq $file) {
                continue
            }

            $typeDir = "$scriptsDir\$($file.Type)"
            New-Item -Path $typeDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            $file.Content | Out-File -FilePath "$typeDir\$($file.Name)" -Encoding default -Force
        }
    }
}

# Group Policy Preferences
if ($imported.PolicySettings.GroupPolicyPreferences) {
    foreach ($gpp in $imported.PolicySettings.GroupPolicyPreferences) {
        $gppDir = "$sysvolRoot\$($gpp.Target)\Preferences\$($gpp.Type)"
        New-Item -Path $gppDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

        $lines = @($gpp.XmlContent | ForEach-Object { Resolve-JsonGPOToken ([string]$_) })
        $lines | Out-File -FilePath "$gppDir\$($gpp.XmlFileName)" -Encoding utf8 -Force
    }
}

# Client-side extensions and the computer/user settings enabled flags
$gpcObject = Get-ADObject -LDAPFilter "(&(objectClass=groupPolicyContainer)(name=$policyGuid))" @serverParams -ErrorAction Stop

if ($imported.gPCMachineExtensionNames) {
    Set-ADObject -Identity $gpcObject.DistinguishedName -Replace @{ gPCMachineExtensionNames = [string]$imported.gPCMachineExtensionNames } @serverParams -ErrorAction Stop
}
if ($imported.gPCUserExtensionNames) {
    Set-ADObject -Identity $gpcObject.DistinguishedName -Replace @{ gPCUserExtensionNames = [string]$imported.gPCUserExtensionNames } @serverParams -ErrorAction Stop
}

# flags: 0 = both enabled, 1 = user disabled, 2 = computer disabled, 3 = both disabled
$computerEnabled = [bool]$imported.ComputerSettingsEnabled
$userEnabled = [bool]$imported.UserSettingsEnabled
$flags = 0
if ($computerEnabled -and -not $userEnabled) { $flags = 1 }
if ((-not $computerEnabled) -and $userEnabled) { $flags = 2 }
if ((-not $computerEnabled) -and (-not $userEnabled)) { $flags = 3 }
Set-ADObject -Identity $gpcObject.DistinguishedName -Replace @{ flags = $flags } @serverParams -ErrorAction Stop

# Bump versionNumber in both AD and SYSVOL's GPT.INI, so GPMC and gpupdate see the change.
if ($incrementBy -gt 0) {
    $current = Get-ADObject -Identity $gpcObject.DistinguishedName -Properties versionNumber @serverParams -ErrorAction Stop
    $newVersion = [uint32]$current.versionNumber + $incrementBy
    Set-ADObject -Identity $gpcObject.DistinguishedName -Replace @{ versionNumber = $newVersion } @serverParams -ErrorAction Stop

    # SYSVOL replication can lag behind the AD object New-GPO just created.
    $gptIniPath = "$sysvolRoot\GPT.INI"
    $attempts = 0
    while (-not (Test-Path -Path $gptIniPath) -and $attempts -lt 30) {
        Start-Sleep -Seconds 1
        $attempts++
    }

    if (Test-Path -Path $gptIniPath) {
        $ini = Get-JsonGPOIniFile -Path $gptIniPath
        $ini['General']['Version'] = $newVersion
        Write-JsonGPOIniFile -Path $gptIniPath -Sections $ini
    }
}

$gpo = Get-GPO -Guid $gpo.Id @serverParams -ErrorAction Stop
Get-BackupGPOResult -Gpo $gpo | ConvertTo-Json -Compress
