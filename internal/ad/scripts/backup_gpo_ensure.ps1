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
    Get-BackupGPOResult -Gpo $gpo | ConvertTo-Json -Compress
}
finally {
    Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction Ignore
}
