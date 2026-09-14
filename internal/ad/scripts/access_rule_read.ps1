$context = Get-AccessRuleContext

try {
    $ace = Find-AccessRuleAce $context
}
catch {
    if ((Test-IsIdentityNotFound $_) -or ($_.Exception -is [System.Management.Automation.ItemNotFoundException])) {
        [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
        return
    }

    throw
}

if ($null -eq $ace) {
    [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
    return
}

Get-AccessRuleResult $context $ace | ConvertTo-Json -Compress
