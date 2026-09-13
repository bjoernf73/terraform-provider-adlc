$domainDN = Get-DomainDN
$serverParams = Get-ServerParams
$group = Get-GroupByIdentity ([string]$payload.guid)

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

# Move before rename so the rename targets the final container.
$targetContainerDN = Convert-PathToDN ([string]$payload.path) $domainDN
$group = Get-GroupByIdentity ([string]$payload.guid)
if ((Get-ParentDN $group.DistinguishedName) -ne $targetContainerDN) {
    Move-ADObject -Identity $group.DistinguishedName -TargetPath $targetContainerDN @serverParams -ErrorAction Stop
    $group = Get-GroupByIdentity ([string]$payload.guid)
}

if ([string]$group.Name -ne [string]$payload.name) {
    Rename-ADObject -Identity $group.DistinguishedName -NewName ([string]$payload.name) @serverParams -ErrorAction Stop
    $group = Get-GroupByIdentity ([string]$payload.guid)
}

Get-GroupResult $group $domainDN | ConvertTo-Json -Compress
