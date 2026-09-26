$keyId = [string]$payload.key_id
$key = Get-KdsRootKeys | Where-Object { $_.KeyId.ToString() -eq $keyId } | Select-Object -First 1

if ($null -eq $key) {
    [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
    return
}

$result = Get-KdsResult $key
$result | Add-Member -NotePropertyName created -NotePropertyValue $false
$result | ConvertTo-Json -Compress
