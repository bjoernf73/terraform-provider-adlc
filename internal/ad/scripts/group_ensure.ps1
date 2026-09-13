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
        SamAccountName = $samAccountName
        Path           = $containerDN
        GroupCategory  = [string]$payload.category
        GroupScope     = [string]$payload.scope
    }

    New-ADGroup @newParams @serverParams -ErrorAction Stop | Out-Null
    $group = Get-GroupByIdentity $targetDN
}

# Reconciles a newly created group and adopts an existing one at the same DN.
$group = Sync-GroupProperties $group

Get-GroupResult $group $domainDN | ConvertTo-Json -Compress
