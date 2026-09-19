Import-Module ActiveDirectory -ErrorAction Stop

$serverParams = Get-ServerParams
$gpoGuid = [string]$payload.gpo_guid

$gpoObject = @(Get-ADObject -LDAPFilter "(&(objectClass=groupPolicyContainer)(name={$gpoGuid}))" -Properties gPCWQLFilter @serverParams -ErrorAction Stop)
if ($gpoObject.Count -gt 0 -and -not [string]::IsNullOrEmpty($gpoObject[0].gPCWQLFilter)) {
    Set-ADObject -Identity $gpoObject[0].DistinguishedName -Clear gPCWQLFilter @serverParams -ErrorAction Stop
}

[pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
