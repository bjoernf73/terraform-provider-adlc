# Reads the GPO's version watermark without the GroupPolicy module: the AD versions come from the
# groupPolicyContainer's versionNumber attribute, the SYSVOL versions from GPT.ini. Both pack the
# computer version in the low word and the user version in the high word.
$domainDN = Get-DomainDN
$guid = [string]$payload.guid
$gpoDN = "CN={$guid},CN=Policies,CN=System,$domainDN"

$entry = Get-ADLCEntry -DistinguishedName $gpoDN -Attributes @('displayName', 'versionNumber', 'flags', 'gPCFileSysPath') -Filter '(objectClass=groupPolicyContainer)'

if ($null -eq $entry) {
    [pscustomobject]@{
        exists                  = $false
        guid                    = $null
        name                    = $null
        distinguished_name      = $null
        domain                  = $null
        status                  = $null
        computer_ad_version     = 0
        computer_sysvol_version = 0
        user_ad_version         = 0
        user_sysvol_version     = 0
    } | ConvertTo-Json -Compress
    return
}

$versionNumber = [int64](Get-ADLCString $entry 'versionNumber')
$computerAdVersion = $versionNumber -band 0xFFFF
$userAdVersion = ($versionNumber -shr 16) -band 0xFFFF

$computerSysvolVersion = 0
$userSysvolVersion = 0
$sysvolPath = Get-ADLCString $entry 'gPCFileSysPath'
if (-not [string]::IsNullOrWhiteSpace($sysvolPath)) {
    $gptIni = Join-Path $sysvolPath 'GPT.ini'
    if (Test-Path -LiteralPath $gptIni) {
        foreach ($line in [System.IO.File]::ReadAllLines($gptIni)) {
            if ($line -match '^\s*Version\s*=\s*(\d+)') {
                $sysvolVersion = [int64]$Matches[1]
                $computerSysvolVersion = $sysvolVersion -band 0xFFFF
                $userSysvolVersion = ($sysvolVersion -shr 16) -band 0xFFFF
                break
            }
        }
    }
}

# The flags attribute maps directly to the GpoStatus enum the GroupPolicy module reports.
switch ([int](Get-ADLCString $entry 'flags')) {
    1 { $status = 'UserSettingsDisabled' }
    2 { $status = 'ComputerSettingsDisabled' }
    3 { $status = 'AllSettingsDisabled' }
    default { $status = 'AllSettingsEnabled' }
}

[pscustomobject]@{
    exists                  = $true
    guid                    = $guid
    name                    = Get-ADLCString $entry 'displayName'
    distinguished_name      = $gpoDN
    domain                  = ConvertFrom-DNToDnsName $domainDN
    status                  = $status
    computer_ad_version     = $computerAdVersion
    computer_sysvol_version = $computerSysvolVersion
    user_ad_version         = $userAdVersion
    user_sysvol_version     = $userSysvolVersion
} | ConvertTo-Json -Compress
