# Managed SYSVOL file-tree helpers. Requires common.ps1.

function Get-SysvolManagedRoot([string]$Kind, [string]$RelativePath) {
    $serverParams = Get-ServerParams
    $domain = Get-ADDomain @serverParams -ErrorAction Stop
    $sysvolHost = if ($payload.domain_controller) { [string]$payload.domain_controller } else { $domain.DNSRoot }

    $root = switch ($Kind) {
        'netlogon' { "\\$sysvolHost\NETLOGON" }
        'administrative_templates' { "\\$sysvolHost\SYSVOL\$($domain.DNSRoot)\Policies\PolicyDefinitions" }
        default { throw "unsupported SYSVOL tree '$Kind'" }
    }

    if ($Kind -eq 'netlogon' -and -not [string]::IsNullOrWhiteSpace($RelativePath)) {
        $root = Join-Path $root $RelativePath
    }
    return $root
}

function Assert-SysvolRelativePath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.StartsWith('/') -or $Path.StartsWith('\\') -or $Path -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "invalid managed relative path '$Path'"
    }
}

function Get-SysvolManagedFilePath([string]$Root, [string]$RelativePath) {
    Assert-SysvolRelativePath $RelativePath
    return Join-Path $Root ($RelativePath -replace '/', '\\')
}

function Remove-SysvolManagedFile([string]$Root, [string]$RelativePath) {
    $filePath = Get-SysvolManagedFilePath $Root $RelativePath
    if (Test-Path -LiteralPath $filePath -PathType Leaf) {
        Remove-Item -LiteralPath $filePath -Force -ErrorAction Stop
    }

    # A directory is removed only when it is actually empty. This preserves files or
    # subdirectories created by another Terraform resource or an administrator.
    $directory = Split-Path -Parent $filePath
    while ($directory -and $directory.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase) -and $directory -ne $Root) {
        $children = @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)
        if ($children.Count -ne 0) { break }
        Remove-Item -LiteralPath $directory -Force -ErrorAction Stop
        $directory = Split-Path -Parent $directory
    }
}

function Get-SysvolFilesResult([string]$Root, $Files) {
    $matches = $true
    foreach ($file in @($Files)) {
        $filePath = Get-SysvolManagedFilePath $Root ([string]$file.path)
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            $matches = $false
            break
        }
        $hash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ($hash -ne [string]$file.sha256) {
            $matches = $false
            break
        }
    }

    return [pscustomobject]@{
        exists  = $true
        matches = $matches
    }
}
