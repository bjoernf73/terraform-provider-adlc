$context = Get-AccessRuleContext

try {
    $acl = Get-Acl -Path (Get-ADObjectAclPath $context.TargetDN) -ErrorAction Stop
}
catch {
    if ((Test-IsIdentityNotFound $_) -or ($_.Exception -is [System.Management.Automation.ItemNotFoundException])) {
        [pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
        return
    }

    throw
}

foreach ($ace in @($acl.Access)) {
    if (Test-AccessRuleKey $ace $context) {
        Get-AccessRuleResult $context $ace | ConvertTo-Json -Compress
        return
    }
}

[pscustomobject]@{ exists = $false } | ConvertTo-Json -Compress
