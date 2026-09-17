$domainDN = Get-DomainDN
$targetDN = Convert-PathToDN ([string]$payload.target) $domainDN
$serverParams = Get-ServerParams

$desired = @($payload.links)
$desiredGuids = @{}
foreach ($entry in $desired) {
    $gpo = Resolve-GPOIdentity ([string]$entry.gpo)
    $desiredGuids[$gpo.Id.ToString().ToUpper()] = $true
}

# Authoritative: drop any link this resource no longer declares before (re)creating the
# rest, so removing an entry from `links` removes it from the OU too.
$current = Get-GPInheritance -Target $targetDN @serverParams -ErrorAction Stop
foreach ($link in @($current.GpoLinks)) {
    $guid = $link.GpoId.ToString().ToUpper()
    if (-not $desiredGuids.ContainsKey($guid)) {
        Remove-GPLink -Guid $link.GpoId -Target $targetDN @serverParams -ErrorAction Stop | Out-Null
    }
}

# Set-GPLink creates the link if missing and updates it in place otherwise, so this loop
# handles both create and update. Ascending order matches the precedence in `links`.
$order = 1
foreach ($entry in $desired) {
    $gpo = Resolve-GPOIdentity ([string]$entry.gpo)
    $linkEnabled = if ([bool]$entry.enabled) { 'Yes' } else { 'No' }
    $enforced = if ([bool]$entry.enforced) { 'Yes' } else { 'No' }

    Set-GPLink -Guid $gpo.Id -Target $targetDN -LinkEnabled $linkEnabled -Enforced $enforced -Order $order @serverParams -ErrorAction Stop | Out-Null
    $order++
}

$isBlocked = if ([bool]$payload.block_inheritance) { 'Yes' } else { 'No' }
Set-GPInheritance -Target $targetDN -IsBlocked $isBlocked @serverParams -ErrorAction Stop | Out-Null

Get-GPOLinksResult -TargetDN $targetDN | ConvertTo-Json -Compress -Depth 5
