# Imports a GPO backup into $payload.target_name, creating it if needed. Re-running this
# against an existing target re-imports the settings in place (same GUID, links kept), so
# it also serves as the update path - see backup_gpo.go.
$tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ([guid]::NewGuid().ToString())
$backupRoot = Join-Path -Path $tempRoot -ChildPath ([string]$payload.backup_name)
New-Item -ItemType Directory -Path $backupRoot -Force -ErrorAction Stop | Out-Null

try {
    Write-BackupGPOFiles -Files $payload.files -Root $backupRoot

    $migrationTablePath = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$payload.migration_table_xml)) {
        $migrationTablePath = Join-Path -Path $tempRoot -ChildPath 'migration.migtable'
        [string]$payload.migration_table_xml | Out-File -FilePath $migrationTablePath -Encoding unicode -Force -ErrorAction Stop
    }

    $serverParams = Get-ServerParams
    $importParams = @{
        BackupGpoName  = [string]$payload.backup_name
        TargetName     = [string]$payload.target_name
        Path           = $backupRoot
        CreateIfNeeded = $true
        ErrorAction    = 'Stop'
    }
    if ($migrationTablePath) {
        $importParams['MigrationTable'] = $migrationTablePath
    }

    Import-GPO @importParams @serverParams | Out-Null

    $gpo = Get-GPO -Name ([string]$payload.target_name) @serverParams -ErrorAction Stop

    # Import-GPO bumps the AD versionNumber at once, but SYSVOL's GPT.ini can lag a few seconds
    # behind. Wait until the on-disk Version matches before recording the watermark: a premature
    # read stores a stale SYSVOL version that the next plan sees as out-of-band drift and
    # "corrects" with a needless re-import, which bumps the version again. See backup_gpo.go.
    $targetVersion = ([int64]$gpo.User.DSVersion -shl 16) -bor ([int64]$gpo.Computer.DSVersion)
    $attempts = 0
    while ((Get-ADLCGptIniVersion ([string]$gpo.Path)) -ne $targetVersion -and $attempts -lt 30) {
        Start-Sleep -Seconds 1
        $attempts++
    }

    Get-BackupGPOResult -Gpo $gpo | ConvertTo-Json -Compress
}
finally {
    Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction Ignore
}
