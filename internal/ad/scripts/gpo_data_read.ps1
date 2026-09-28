$domainDN = Get-DomainDN
$identity = [string]$payload.identity

try {
    $gpo = Get-GPOByIdentity $identity
}
catch {
    $message = $_.Exception.Message
    if (($message -match 'was not found') -or ($message -match 'cannot find') -or ($message -match 'does not exist')) {
        throw "GPO '$identity' not found"
    }

    throw
}

Get-GPOResult $gpo $domainDN | ConvertTo-Json -Compress
