# Memberships are imported as "<group>/<member>", where each side accepts a
# distinguished name, objectGUID, SID or sAMAccountName.
terraform import adlc_group_member.svc_backup "SERVER-ADMINS/svc-backup"
