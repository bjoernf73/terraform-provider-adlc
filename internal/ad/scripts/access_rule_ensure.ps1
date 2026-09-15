$context = Get-AccessRuleContext

$ignoreAdminCount1 = $false
if ($null -ne $payload.ignore_admin_count_1) {
    $ignoreAdminCount1 = [bool]$payload.ignore_admin_count_1
}
Assert-NotAdminCountProtected $context.TargetDN $ignoreAdminCount1

$aclPath = Get-ADObjectAclPath $context.TargetDN
$acl = Get-Acl -Path $aclPath -ErrorAction Stop

# Drop any existing ACE with the same key first, so a rights change is one atomic
# write rather than a revoke followed by a grant.
foreach ($ace in @($acl.Access)) {
    if (Test-AccessRuleKey $ace $context) {
        $acl.RemoveAccessRuleSpecific($ace)
    }
}

$rule = New-ADAccessRule $context
$acl.AddAccessRule($rule)
Set-Acl -Path $aclPath -AclObject $acl -ErrorAction Stop

# Built from the rule just written, not re-read from the server: a Get-Acl immediately
# after Set-Acl on the same object can race the write and miss it, and there is nothing
# a fresh read would tell us that we do not already know about our own write.
Get-AccessRuleResult $context $rule | ConvertTo-Json -Compress
