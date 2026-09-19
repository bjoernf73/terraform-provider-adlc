$root = Get-SysvolManagedRoot ([string]$payload.kind) ([string]$payload.relative_path)
New-Item -ItemType Directory -Path $root -Force -ErrorAction Stop | Out-Null

$desiredPaths = @($payload.files | ForEach-Object { [string]$_.path })
foreach ($previousPath in @($payload.previous_paths)) {
    if ([string]$previousPath -notin $desiredPaths) {
        Remove-SysvolManagedFile $root ([string]$previousPath)
    }
}

foreach ($file in @($payload.files)) {
    $filePath = Get-SysvolManagedFilePath $root ([string]$file.path)
    $parent = Split-Path -Parent $filePath
    New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop | Out-Null
    [System.IO.File]::WriteAllBytes($filePath, [System.Convert]::FromBase64String([string]$file.content))
}

Get-SysvolFilesResult $root $payload.files | ConvertTo-Json -Compress
