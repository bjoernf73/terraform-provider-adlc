# GPO link helpers. Requires common.ps1.
Import-Module GroupPolicy -ErrorAction Stop

# $Identity is a GUID or a GPO display name, exactly as the caller wrote it.
function Resolve-GPOIdentity([string]$Identity) {
    $serverParams = Get-ServerParams
    $parsed = [guid]::Empty
    if ([guid]::TryParse($Identity, [ref]$parsed)) {
        return Get-GPO -Guid $parsed @serverParams -ErrorAction Stop
    }
    return Get-GPO -Name $Identity @serverParams -ErrorAction Stop
}

function Test-IsGPOLinkTargetNotFound($ErrorRecord) {
    if ($null -eq $ErrorRecord) {
        return $false
    }

    $message = $ErrorRecord.Exception.Message
    return ($message -match 'cannot find an object') -or ($message -match 'could not find') -or ($message -match 'does not exist')
}

# Reads the full, ordered set of links plus the inheritance-blocked flag for $TargetDN.
function Get-GPOLinksResult([string]$TargetDN) {
    $serverParams = Get-ServerParams
    $inheritance = Get-GPInheritance -Target $TargetDN @serverParams -ErrorAction Stop

    $links = @()
    foreach ($link in @($inheritance.GpoLinks | Sort-Object -Property Order)) {
        $links += [pscustomobject]@{
            gpo_guid = $link.GpoId.ToString()
            gpo_name = $link.DisplayName
            enabled  = [bool]$link.Enabled
            enforced = [bool]$link.Enforced
            order    = [int]$link.Order
        }
    }

    return [pscustomobject]@{
        exists            = $true
        target_dn         = $TargetDN
        block_inheritance = ($inheritance.GpoInheritanceBlocked -eq 'Yes')
        links             = $links
    }
}
