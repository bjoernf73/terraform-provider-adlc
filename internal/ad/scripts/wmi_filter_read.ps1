Import-Module ActiveDirectory -ErrorAction Stop

$guid = [string]$payload.guid
$adObject = Get-WmiFilterByGuid $guid

Get-WmiFilterResult $adObject | ConvertTo-Json -Compress -Depth 5
