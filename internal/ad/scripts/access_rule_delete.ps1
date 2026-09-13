$context = Get-AccessRuleContext

try {
    $aclPath = Get-ADObjectAclPath $context.TargetDN
    $acl = Get-Acl -Path $aclPath -ErrorAction Stop
}
catch {
    if ((Test-IsIdentityNotFound $_) -or ($_.Exception -is [System.Management.Automation.ItemNotFoundException])) {
        [pscustomobject]@{ deleted = $false; exists = $false } | ConvertTo-Json -Compress
        return
    }

    throw
}

# Only ACEs this resource owns are removed; inherited and unrelated ACEs are left alone.
$removed = $false
foreach ($ace in @($acl.Access)) {
    if (Test-AccessRuleKey $ace $context) {
        $acl.RemoveAccessRuleSpecific($ace)
        $removed = $true
    }
}

if ($removed) {
    Set-Acl -Path $aclPath -AclObject $acl -ErrorAction Stop
}

[pscustomobject]@{ deleted = $removed; exists = $false } | ConvertTo-Json -Compress
