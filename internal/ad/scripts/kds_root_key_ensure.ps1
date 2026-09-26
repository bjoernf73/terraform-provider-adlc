$existing = Get-KdsRootKeys
$created = $false

if ($existing.Count -eq 0) {
    if ([bool]$payload.effective_immediately) {
        # Backdate the effective time by 10 hours so the key is usable at once, bypassing the
        # replication safety window. Sound only when every DC that will serve the gMSA has the
        # key, which in a single-DC forest is immediate.
        $null = Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10)) -ErrorAction Stop
    }
    else {
        # Default timing: the key becomes effective 10 hours from now.
        $null = Add-KdsRootKey -ErrorAction Stop
    }

    $created = $true
    $existing = Get-KdsRootKeys
}

$key = Select-KdsRootKey $existing
if ($null -eq $key) {
    throw 'no KDS root key is present after ensuring one exists'
}

# Only force replication for a key this run created; adopting a pre-existing key means it has
# already had time to replicate.
if ($created -and [bool]$payload.force_replication) {
    $null = Invoke-KdsRootKeyReplication $key
}

$result = Get-KdsResult $key
$result | Add-Member -NotePropertyName created -NotePropertyValue $created
$result | ConvertTo-Json -Compress
