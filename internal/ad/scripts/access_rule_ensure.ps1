$context = Get-AccessRuleContext
$aclPath = Get-ADObjectAclPath $context.TargetDN
$acl = Get-Acl -Path $aclPath -ErrorAction Stop

# Drop any existing ACE with the same key first, so a rights change is one atomic
# write rather than a revoke followed by a grant.
foreach ($ace in @($acl.Access)) {
    if (Test-AccessRuleKey $ace $context) {
        $acl.RemoveAccessRuleSpecific($ace)
    }
}

$acl.AddAccessRule((New-ADAccessRule $context))
Set-Acl -Path $aclPath -AclObject $acl -ErrorAction Stop

# Find-AccessRuleAce retries briefly: a read immediately after this write can race it.
$ace = Find-AccessRuleAce $context
if ($null -eq $ace) {
    throw 'the access rule was written but could not be read back'
}

Get-AccessRuleResult $context $ace | ConvertTo-Json -Compress
