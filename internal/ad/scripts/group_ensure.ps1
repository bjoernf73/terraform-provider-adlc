$domainDN = Get-DomainDN
$serverParams = Get-ServerParams
$containerDN = Convert-PathToDN ([string]$payload.path) $domainDN
$targetDN = 'CN=' + [string]$payload.name + ',' + $containerDN

$group = Get-GroupOrNull $targetDN
if ($null -eq $group) {
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
