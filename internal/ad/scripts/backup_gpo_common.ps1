# Backup GPO helpers. Requires common.ps1.
Import-Module GroupPolicy -ErrorAction Stop

# Writes the files carried in the payload (each {path, content}) under $Root, which must
# already exist. $Files is the deserialized $payload.files array: content is base64.
function Write-BackupGPOFiles($Files, [string]$Root) {
    foreach ($file in @($Files)) {
        $destination = Join-Path -Path $Root -ChildPath ([string]$file.path)
        $parent = Split-Path -Path $destination -Parent
        if (-not (Test-Path -Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop | Out-Null
        }

        $bytes = [System.Convert]::FromBase64String([string]$file.content)
        [System.IO.File]::WriteAllBytes($destination, $bytes)
    }
}

function Test-IsGPONotFound($ErrorRecord) {
    if ($null -eq $ErrorRecord) {
        return $false
    }

    $message = $ErrorRecord.Exception.Message
    return ($message -match 'could not be found') -or ($message -match 'was not found') -or ($message -match 'does not exist')
}

# $Gpo is the Microsoft.GroupPolicy.Gpo object returned by Get-GPO, or $null when it does
# not exist.
function Get-BackupGPOResult($Gpo) {
    if ($null -eq $Gpo) {
        return [pscustomobject]@{
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
        }
    }

    return [pscustomobject]@{
        exists                  = $true
        guid                    = $Gpo.Id.ToString()
        name                    = $Gpo.DisplayName
        distinguished_name      = ([string]$Gpo.Path -replace '^LDAP://', '')
        domain                  = $Gpo.DomainName
        status                  = $Gpo.GpoStatus.ToString()
        computer_ad_version     = [int64]$Gpo.Computer.DSVersion
        computer_sysvol_version = [int64]$Gpo.Computer.SysvolVersion
        user_ad_version         = [int64]$Gpo.User.DSVersion
        user_sysvol_version     = [int64]$Gpo.User.SysvolVersion
    }
}
