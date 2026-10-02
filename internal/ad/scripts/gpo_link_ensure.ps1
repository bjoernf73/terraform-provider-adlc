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
# rest, so removing an entry from `links` removes it from the OU too. Capture which desired
# GPOs are already linked, so the reconcile loop can tell create from update.
$current = Get-GPInheritance -Target $targetDN @serverParams -ErrorAction Stop
$currentGuids = @{}
foreach ($link in @($current.GpoLinks)) {
    $guid = $link.GpoId.ToString().ToUpper()
    $currentGuids[$guid] = $true
    if (-not $desiredGuids.ContainsKey($guid)) {
        Remove-GPLink -Guid $link.GpoId -Target $targetDN @serverParams -ErrorAction Stop | Out-Null
    }
}

# New-GPLink creates a missing link; Set-GPLink only updates an existing one and errors if the
# link is absent, so each entry is routed by whether the GPO is already linked. Ascending order
# matches the precedence in `links`.
$order = 1
foreach ($entry in $desired) {
    $gpo = Resolve-GPOIdentity ([string]$entry.gpo)
    $linkEnabled = if ([bool]$entry.enabled) { 'Yes' } else { 'No' }
    $enforced = if ([bool]$entry.enforced) { 'Yes' } else { 'No' }

    if ($currentGuids.ContainsKey($gpo.Id.ToString().ToUpper())) {
        Set-GPLink -Guid $gpo.Id -Target $targetDN -LinkEnabled $linkEnabled -Enforced $enforced -Order $order @serverParams -ErrorAction Stop | Out-Null
    }
    else {
        New-GPLink -Guid $gpo.Id -Target $targetDN -LinkEnabled $linkEnabled -Enforced $enforced -Order $order @serverParams -ErrorAction Stop | Out-Null
    }
    $order++
}

$isBlocked = if ([bool]$payload.block_inheritance) { 'Yes' } else { 'No' }
Set-GPInheritance -Target $targetDN -IsBlocked $isBlocked @serverParams -ErrorAction Stop | Out-Null

Get-GPOLinksResult -TargetDN $targetDN | ConvertTo-Json -Compress -Depth 5
