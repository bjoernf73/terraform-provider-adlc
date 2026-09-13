$domainDN = Get-DomainDN
$serverParams = Get-ServerParams
$containerDN = Convert-PathToDN ([string]$payload.path) $domainDN
$targetDN = 'CN=' + [string]$payload.name + ',' + $containerDN

$group = Get-GroupOrNull $targetDN
if ($null -eq $group) {
    # sAMAccountName is unique domain-wide, so report a conflict outside this container clearly.
    # The filter is single-quoted so the AD parser binds $samAccountName instead of string interpolation.
    $samAccountName = [string]$payload.sam_account_name
    $conflict = @(Get-ADGroup -Filter 'SamAccountName -eq $samAccountName' @serverParams -ErrorAction Stop)
    if ($conflict.Count -gt 0) {
        throw "a group with sAMAccountName '$samAccountName' already exists at '$($conflict[0].DistinguishedName)'"
    }

    $newParams = @{
        Name           = [string]$payload.name
        SamAccountName = [string]$payload.sam_account_name
        Path           = $containerDN
        GroupCategory  = [string]$payload.category
        GroupScope     = [string]$payload.scope
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$payload.description)) {
        $newParams['Description'] = [string]$payload.description
    }

    New-ADGroup @newParams @serverParams -ErrorAction Stop | Out-Null
    $group = Get-GroupByIdentity $targetDN
}
else {
    # Adopt an existing group at the same DN and reconcile it to the configuration.
    $setParams = @{}
    if ([string]$group.SamAccountName -ne [string]$payload.sam_account_name) {
        $setParams['SamAccountName'] = [string]$payload.sam_account_name
    }
    if ([string]$group.GroupCategory -ne [string]$payload.category) {
        $setParams['GroupCategory'] = [string]$payload.category
    }
    if ([string]$group.GroupScope -ne [string]$payload.scope) {
        $setParams['GroupScope'] = [string]$payload.scope
    }

    if ($setParams.Count -gt 0) {
        Set-ADGroup -Identity $group.DistinguishedName @setParams @serverParams -ErrorAction Stop
    }

    if ([string]::IsNullOrWhiteSpace([string]$payload.description)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$group.Description)) {
            Set-ADGroup -Identity $group.DistinguishedName -Clear Description @serverParams -ErrorAction Stop
        }
    }
    elseif ([string]$group.Description -ne [string]$payload.description) {
        Set-ADGroup -Identity $group.DistinguishedName -Description ([string]$payload.description) @serverParams -ErrorAction Stop
    }

    $group = Get-GroupByIdentity $group.DistinguishedName
}

Get-GroupResult $group $domainDN | ConvertTo-Json -Compress
