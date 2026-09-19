# Static Terraform translation of dry.module.ad's domain-config fixture.
# Unlike ../domain-config, this file has no jsondecode, fileset, or ref/ dependency.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    adlc = {
      source  = "henrikhalt/adlc"
      version = "0.0.0-ci"
    }
  }
}

data "adlc_domain" "current" {}

locals {
  ou_definitions = {
    "DomainControllers" = {
      "path"        = "Domain Controllers"
      "description" = "Domain Controllers OU"
    }
    "Computer-Servers" = {
      "path"        = "${var.organization}/Servers"
      "description" = "Root OU for Server Computer Objects"
    }
    "Computer-Servers-Win" = {
      "path"        = "${var.organization}/Servers/Win"
      "description" = "Root OU for Server Computer Objects"
    }
    "Computer-Servers-Lin" = {
      "path"        = "${var.organization}/Servers/Lin"
      "description" = "OU for Linux Server Computer Objects"
    }
    "Computer-Workstations" = {
      "path"        = "${var.organization}/Workstations"
      "description" = "Root OU for Server Computer Objects"
    }
    "Computer-Workstations-Win" = {
      "path"        = "${var.organization}/Workstations/Win"
      "description" = "Root OU for Server Computer Objects"
    }
    "Roles-Root" = {
      "path"        = "${var.organization}/Roles"
      "description" = "Root OU for Role groups"
    }
    "Roles" = {
      "path"        = "${var.organization}/Roles/${var.role_short_name}"
      "description" = "OU for Roles of role '${var.role_short_name}'"
    }
    "Roles-Protected" = {
      "path"        = "${var.organization}/Roles/Protected"
      "description" = "OU for Protected Role groups (groups with AdminCount=1)"
    }
    "Rights-Root" = {
      "path"        = "${var.organization}/Rights"
      "description" = "Root OU for Rights groups"
    }
    "Rights" = {
      "path"        = "${var.organization}/Rights/${var.role_short_name}"
      "description" = "OU for Rights of role '${var.role_short_name}'"
    }
    "Rights-Protected" = {
      "path"        = "${var.organization}/Rights/Protected"
      "description" = "OU for Protected Rights groups (groups with AdminCount=1)"
    }
    "Groups-EndUser" = {
      "path"        = "${var.organization}/EndUserGroups"
      "description" = "End user groups OU"
    }
    "Groups-EndUser-AppGroups" = {
      "path"        = "${var.organization}/EndUserGroups/ApplicationGroups"
      "description" = "End user group giving install right to an application"
    }
    "Groups-EndUser-DepartmentGroups" = {
      "path"        = "${var.organization}/EndUserGroups/DepartmentGroups"
      "description" = "End user groups of the organizational structure"
    }
    "Groups-EndUser-DistributionGroups" = {
      "path"        = "${var.organization}/EndUserGroups/DistributionGroups"
      "description" = "Mail enabled distribution groups"
    }
    "Groups-EndUser-CooperationGroups" = {
      "path"        = "${var.organization}/EndUserGroups/CooperationGroups"
      "description" = "End user cooperation groups. For cooperations across and beyond department or project groups"
    }
    "Groups-EndUser-ProjectGroups" = {
      "path"        = "${var.organization}/EndUserGroups/ProjectGroups"
      "description" = "End user Project groups"
    }
    "Users" = {
      "path"        = "${var.organization}/Users"
      "description" = "User objects of any type"
    }
    "Users-EndUsers" = {
      "path"        = "${var.organization}/Users/EndUsers"
      "description" = "End user objects"
    }
    "Users-AdmUsers" = {
      "path"        = "${var.organization}/Users/AdmUsers"
      "description" = "Adm user objects"
    }
    "Users-SvcUsers" = {
      "path"        = "${var.organization}/Users/SvcUsers"
      "description" = "Svc user objects"
    }
    "Users-DeployUsers" = {
      "path"        = "${var.organization}/Users/DeployUsers"
      "description" = "Deployment user objects"
    }
    "Users-MsaUsers" = {
      "path"        = "${var.organization}/Users/MsaUsers"
      "description" = "Managed Service Accounts"
    }
  }

  group_definitions = {
    "Right-AD-Group-DomainAdmins-Member" = {
      "name"        = "Right-AD-Group-DomainAdmins-Member"
      "alias"       = "Rights-Protected"
      "description" = "Member of Domain Admins in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "Global"
      "member_of" = [
        "Domain Admins"
      ]
    }
    "Right-AD-Group-EnterpriseAdmins-Member" = {
      "name"        = "Right-AD-Group-EnterpriseAdmins-Member"
      "alias"       = "Rights-Protected"
      "description" = "Member of Enterprise Admins in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "Global"
      "member_of" = [
        "Enterprise Admins"
      ]
    }
    "Right-AD-Group-SchemaAdmins-Member" = {
      "name"        = "Right-AD-Group-SchemaAdmins-Member"
      "alias"       = "Rights-Protected"
      "description" = "Member of Schema Admins in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "Global"
      "member_of" = [
        "Schema Admins"
      ]
    }
    "Right-AD-Group-AllowedRODCpwdrepl-Member" = {
      "name"        = "Right-AD-Group-AllowedRODCpwdrepl-Member"
      "alias"       = "Rights"
      "description" = "Member of 'Allowed RODC Password Replication Group' in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "DomainLocal"
      "member_of" = [
        "Allowed RODC Password Replication Group"
      ]
    }
    "Right-AD-Group-DeniedRODCpwdrepl-Member" = {
      "name"        = "Right-AD-Group-DeniedRODCpwdrepl-Member"
      "alias"       = "Rights"
      "description" = "Member of 'Denied RODC Password Replication Group' in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "DomainLocal"
      "member_of" = [
        "Denied RODC Password Replication Group"
      ]
    }
    "Right-AD-Group-CertPublishers-Member" = {
      "name"        = "Right-AD-Group-CertPublishers-Member"
      "alias"       = "Rights"
      "description" = "Member of 'Cert Publishers' in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "DomainLocal"
      "member_of" = [
        "Cert Publishers"
      ]
    }
    "Right-AD-Group-DNSAdmins-Member" = {
      "name"        = "Right-AD-Group-DNSAdmins-Member"
      "alias"       = "Rights"
      "description" = "Member of 'DnsAdmins' in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "DomainLocal"
      "member_of" = [
        "DnsAdmins"
      ]
    }
    "Right-AD-Group-DNSUpdateProxy-Member" = {
      "name"        = "Right-AD-Group-DNSUpdateProxy-Member"
      "alias"       = "Rights"
      "description" = "Member of 'DnsUpdateProxy' in domain '${data.adlc_domain.current.dns_root}'. For DHCP Servers as members."
      "scope"       = "Global"
      "member_of" = [
        "DnsUpdateProxy"
      ]
    }
    "Right-AD-Group-EnterpriseKeyAdmins-Member" = {
      "name"        = "Right-AD-Group-EnterpriseKeyAdmins-Member"
      "alias"       = "Rights"
      "description" = "Member of 'Enterprise Key Admins' in forest '${data.adlc_domain.current.dns_root}'"
      "scope"       = "Universal"
      "member_of" = [
        "Enterprise Key Admins"
      ]
    }
    "Right-AD-Group-KeyAdmins-Member" = {
      "name"        = "Right-AD-Group-KeyAdmins-Member"
      "alias"       = "Rights"
      "description" = "Member of 'Key Admins' in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "Global"
      "member_of" = [
        "Key Admins"
      ]
    }
    "Right-AD-Group-ProtectedUsers-Member" = {
      "name"        = "Right-AD-Group-ProtectedUsers-Member"
      "alias"       = "Rights"
      "description" = "Member of 'Protected Users' in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "Global"
      "member_of" = [
        "Protected Users"
      ]
    }
    "Right-AD-Group-RASandIASservers-Member" = {
      "name"        = "Right-AD-Group-RASandIASservers-Member"
      "alias"       = "Rights"
      "description" = "Member of 'RAS and IAS Servers' in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "DomainLocal"
      "member_of" = [
        "RAS and IAS Servers"
      ]
    }
    "Right-AD-Computer-Servers-CreMoDel" = {
      "name"        = "Right-AD-Computer-Servers-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete Server computer objects"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Computer-Servers-Windows-CreMoDel" = {
      "name"        = "Right-AD-Computer-Servers-Windows-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete Windows Server computer objects"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Computer-Servers-Windows-LAPSread" = {
      "name"        = "Right-AD-Computer-Servers-Windows-LAPSread"
      "alias"       = "Rights"
      "description" = "Right to Read LAPS Password on Windows Server computer objects"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Computer-Servers-Windows-LAPSmodify" = {
      "name"        = "Right-AD-Computer-Servers-Windows-LAPSmodify"
      "alias"       = "Rights"
      "description" = "Right to Read and Modify LAPS Password on Windows Server computer objects"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Computer-Servers-Linux-CreMoDel" = {
      "name"        = "Right-AD-Computer-Servers-Linux-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete Linux Server computer objects"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Computer-Workstations-CreMoDel" = {
      "name"        = "Right-AD-Computer-Workstations-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete Workstation computer objects"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Computer-ComputersCN-CreMoDel" = {
      "name"        = "Right-AD-Computer-ComputersCN-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete computer objects in the CN=Computers Container, used in manual domain join (and move to role OU)"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-CreMoDel" = {
      "name"        = "Right-AD-Group-EndUser-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete AD groups below OU 'EndUserGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-ModifyMembers" = {
      "name"        = "Right-AD-Group-EndUser-ModifyMembers"
      "alias"       = "Rights"
      "description" = "Right to Modify Members of AD Groups below OU 'EndUserGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-App-CreMoDel" = {
      "name"        = "Right-AD-Group-EndUser-App-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete AD Groups below OU 'AppGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-App-ModifyMembers" = {
      "name"        = "Right-AD-Group-EndUser-App-ModifyMembers"
      "alias"       = "Rights"
      "description" = "Right to Modify Members of AD Groups below OU 'AppGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-Project-CreMoDel" = {
      "name"        = "Right-AD-Group-EndUser-Project-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete AD Groups below OU 'ProjectGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-Project-ModifyMembers" = {
      "name"        = "Right-AD-Group-EndUser-Project-ModifyMembers"
      "alias"       = "Rights"
      "description" = "Right to Modify Members of AD Groups below OU 'ProjectGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-Department-CreMoDel" = {
      "name"        = "Right-AD-Group-EndUser-Department-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete AD Groups below OU 'DepartmentGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-Department-ModifyMembers" = {
      "name"        = "Right-AD-Group-EndUser-Department-ModifyMembers"
      "alias"       = "Rights"
      "description" = "Right to Modify Members of AD Groups below OU 'DepartmentGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-Distribution-CreMoDel" = {
      "name"        = "Right-AD-Group-EndUser-Distribution-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete AD Groups below OU 'DistributionGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-Distribution-ModifyMembers" = {
      "name"        = "Right-AD-Group-EndUser-Distribution-ModifyMembers"
      "alias"       = "Rights"
      "description" = "Right to Modify Members of AD Groups below OU 'DistributionGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-Cooperation-CreMoDel" = {
      "name"        = "Right-AD-Group-EndUser-Cooperation-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete AD Groups below OU 'CooperationGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-EndUser-Cooperation-ModifyMembers" = {
      "name"        = "Right-AD-Group-EndUser-Cooperation-ModifyMembers"
      "alias"       = "Rights"
      "description" = "Right to Modify Members of AD Groups below OU 'CooperationGroups'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-Rights-CreMoDel" = {
      "name"        = "Right-AD-Group-Rights-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete AD Groups below OU 'Rights'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-Rights-ModifyMembers" = {
      "name"        = "Right-AD-Group-Rights-ModifyMembers"
      "alias"       = "Rights"
      "description" = "Right to Modify Members of AD Groups below OU 'Rights'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-Roles-CreMoDel" = {
      "name"        = "Right-AD-Group-Roles-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete AD Groups below OU 'Roles'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Group-Roles-ModifyMembers" = {
      "name"        = "Right-AD-Group-Roles-ModifyMembers"
      "alias"       = "Rights"
      "description" = "Right to Modify Members of AD Groups below OU 'Roles'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Users-CreMoDel" = {
      "name"        = "Right-AD-Users-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete Users below OU 'Users'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Users-AdmUsers-CreMoDel" = {
      "name"        = "Right-AD-Users-AdmUsers-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete Users below OU 'Users-AdmUsers'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Users-EndUsers-CreMoDel" = {
      "name"        = "Right-AD-Users-EndUsers-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete Users below OU 'Users-EndUsers'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Users-SvcUsers-CreMoDel" = {
      "name"        = "Right-AD-Users-SvcUsers-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete Users below OU 'Users-SvcUsers'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-Users-MsaUsers-CreMoDel" = {
      "name"        = "Right-AD-Users-MsaUsers-CreMoDel"
      "alias"       = "Rights"
      "description" = "Right to CREate, MODify and DELete Users below OU 'Users-MsaUsers'. "
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-AD-PKI-FullAccess" = {
      "name"        = "Right-AD-PKI-FullAccess"
      "alias"       = "Rights"
      "description" = "Full access to 'CN=Public Key Services,CN=Services,CN=Configuration'. Used by Certificate Services"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Role-AD-DomainAdmins" = {
      "name"        = "Role-AD-DomainAdmins"
      "alias"       = "Roles-Protected"
      "description" = "Domain Admins in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "Global"
      "member_of" = [
        "Right-AD-Group-DomainAdmins-Member"
      ]
    }
    "Role-AD-EnterpriseAdmins" = {
      "name"        = "Role-AD-EnterpriseAdmins"
      "alias"       = "Roles-Protected"
      "description" = "Enterprise Admins in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "Global"
      "member_of" = [
        "Right-AD-Group-EnterpriseAdmins-Member"
      ]
    }
    "Role-AD-SchemaAdmins" = {
      "name"        = "Role-AD-SchemaAdmins"
      "alias"       = "Roles-Protected"
      "description" = "Schema Admins in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "Global"
      "member_of" = [
        "Right-AD-Group-SchemaAdmins-Member"
      ]
    }
    "Role-AD-FullAdmins" = {
      "name"        = "Role-AD-FullAdmins"
      "alias"       = "Roles-Protected"
      "description" = "Domain-, Enterprise- and Schema Admin in domain '${data.adlc_domain.current.dns_root}'"
      "scope"       = "Global"
      "member_of" = [
        "Right-AD-Group-DomainAdmins-Member",
        "Right-AD-Group-EnterpriseAdmins-Member",
        "Right-AD-Group-SchemaAdmins-Member"
      ]
    }
    "Role-AD-RBACOperator" = {
      "name"        = "Role-AD-RBACOperator"
      "alias"       = "Roles"
      "description" = "Role for delegation of right to modify members in role groups"
      "scope"       = "DomainLocal"
      "member_of" = [
        "Right-AD-Group-Roles-modifymembers"
      ]
    }
    "Role-AD-ADOperator" = {
      "name"        = "Role-AD-ADOperator"
      "alias"       = "Roles"
      "description" = "General AD Operations role"
      "scope"       = "DomainLocal"
      "member_of" = [
        "Right-AD-Group-CertPublishers-Member",
        "Right-AD-Group-DnsAdmins-Member",
        "Right-AD-Computer-Servers-CreMoDel",
        "Right-AD-Computer-Workstations-CreMoDel",
        "Right-AD-Computer-Servers-windows-LAPSmodify",
        "Right-AD-Computer-ComputersCN-CreMoDel",
        "Right-AD-Group-EndUser-CreMoDel",
        "Right-AD-Group-Rights-CreMoDel",
        "Right-AD-Group-Roles-CreMoDel",
        "Right-AD-Users-CreMoDel"
      ]
    }
    "Role-AD-DHCPServers" = {
      "name"        = "Role-AD-DHCPServers"
      "alias"       = "Roles"
      "description" = "General AD Operations role"
      "scope"       = "Global"
      "member_of" = [
        "Right-AD-Group-DnsUpdateProxy-Member"
      ]
    }
    "Role-AD-cadeploy" = {
      "name"        = "Role-AD-cadeploy"
      "alias"       = "Roles"
      "description" = "General AD Operations role"
      "scope"       = "Global"
      "member_of" = [
        "Right-AD-PKI-FullAccess",
        "Right-AD-Group-CertPublishers-Member",
        "Right-DC-BuiltinGroup-BackupOperators"
      ]
    }
    "Right-DC-BuiltinGroup-AccessControlAssistanceOperators" = {
      "name"        = "Right-DC-BuiltinGroup-AccessControlAssistanceOperators"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Access Control Assistance Operators'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-BackupOperators" = {
      "name"        = "Right-DC-BuiltinGroup-BackupOperators"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Backup Operators'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-CertificateServiceDCOMAccess" = {
      "name"        = "Right-DC-BuiltinGroup-CertificateServiceDCOMAccess"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'CertificateServiceDCOMAccess'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-CryptographicOperators" = {
      "name"        = "Right-DC-BuiltinGroup-CryptographicOperators"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Cryptographic Operators'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-DistributedCOMUsers" = {
      "name"        = "Right-DC-BuiltinGroup-DistributedCOMUsers"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Distributed COM Users'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-EventLogReaders" = {
      "name"        = "Right-DC-BuiltinGroup-EventLogReaders"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Event Log Readers'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-PerformanceLogUsers" = {
      "name"        = "Right-DC-BuiltinGroup-PerformanceLogUsers"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Performance Log Users'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-PerformanceMonitorUsers" = {
      "name"        = "Right-DC-BuiltinGroup-PerformanceMonitorUsers"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Performance Monitor Users'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-RemoteDesktopUsers" = {
      "name"        = "Right-DC-BuiltinGroup-RemoteDesktopUsers"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Remote Desktop Users'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-RemoteManagementUsers" = {
      "name"        = "Right-DC-BuiltinGroup-RemoteManagementUsers"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Remote Management Users'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-Replicator" = {
      "name"        = "Right-DC-BuiltinGroup-Replicator"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Replicator'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-TerminalServerLicenseServers" = {
      "name"        = "Right-DC-BuiltinGroup-TerminalServerLicenseServers"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Terminal Server License Servers'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-BuiltinGroup-WindowsAuthorizationAccessGroup" = {
      "name"        = "Right-DC-BuiltinGroup-WindowsAuthorizationAccessGroup"
      "alias"       = "Rights"
      "description" = "Right DC: Member of local group 'Windows Authorization Access Group'"
      "scope"       = "Global"
      "member_of"   = []
    }
    "Right-DC-URA-SeSecurityPrivilege" = {
      "name"        = "Right-DC-URA-SeSecurityPrivilege"
      "alias"       = "Rights"
      "description" = "Role DC: URA 'Manage Auditing and Security Log' (SeSecurityPrivilege)"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-DC-URA-SeShutdownPrivilege" = {
      "name"        = "Right-DC-URA-SeShutdownPrivilege"
      "alias"       = "Rights"
      "description" = "Right DC: URA 'Shut down the system' (SeShutdownPrivilege)"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-DC-URA-SeRemoteShutdownPrivilege" = {
      "name"        = "Right-DC-URA-SeRemoteShutdownPrivilege"
      "alias"       = "Rights"
      "description" = "Right DC: URA 'Force shutdown from a remote system' (SeRemoteShutdownPrivilege)"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-DC-URA-SeIncreaseQuotaPrivilege" = {
      "name"        = "Right-DC-URA-SeIncreaseQuotaPrivilege"
      "alias"       = "Rights"
      "description" = "Right DC: URA 'Adjust Memory Quotas for a Process' (SeIncreaseQuotaPrivilege)"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-DC-URA-SeDelegateSessionUserImpersonatePrivilege" = {
      "name"        = "Right-DC-URA-SeDelegateSessionUserImpersonatePrivilege"
      "alias"       = "Rights"
      "description" = "Right DC: URA 'Obtain impersonation token for another user in the same session' (SeDelegateSessionUserImpersonatePrivilege)"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-DC-URA-SeRelabelPrivilege" = {
      "name"        = "Right-DC-URA-SeRelabelPrivilege"
      "alias"       = "Rights"
      "description" = "Right DC: URA 'Modify an object label' (SeRelabelPrivilege)"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-DC-URA-SeIncreaseWorkingSetPrivilege" = {
      "name"        = "Right-DC-URA-SeIncreaseWorkingSetPrivilege"
      "alias"       = "Rights"
      "description" = "Right DC: URA 'Increase a process working set' (SeIncreaseWorkingSetPrivilege)"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-DC-URA-SeAssignPrimaryTokenPrivilege" = {
      "name"        = "Right-DC-URA-SeAssignPrimaryTokenPrivilege"
      "alias"       = "Rights"
      "description" = "Right DC: URA 'Replace a process-level token' (SeAssignPrimaryTokenPrivilege)"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
    "Right-DC-URA-SeSystemProfilePrivilege" = {
      "name"        = "Right-DC-URA-SeSystemProfilePrivilege"
      "alias"       = "Rights"
      "description" = "Right DC: URA 'Profile system performance' (SeSystemProfilePrivilege)"
      "scope"       = "DomainLocal"
      "member_of"   = []
    }
  }

  group_memberships = {
    "Right-AD-Group-DomainAdmins-Member|Domain Admins" = {
      "member" = "Right-AD-Group-DomainAdmins-Member"
      "group"  = "Domain Admins"
    }
    "Right-AD-Group-EnterpriseAdmins-Member|Enterprise Admins" = {
      "member" = "Right-AD-Group-EnterpriseAdmins-Member"
      "group"  = "Enterprise Admins"
    }
    "Right-AD-Group-SchemaAdmins-Member|Schema Admins" = {
      "member" = "Right-AD-Group-SchemaAdmins-Member"
      "group"  = "Schema Admins"
    }
    "Right-AD-Group-AllowedRODCpwdrepl-Member|Allowed RODC Password Replication Group" = {
      "member" = "Right-AD-Group-AllowedRODCpwdrepl-Member"
      "group"  = "Allowed RODC Password Replication Group"
    }
    "Right-AD-Group-DeniedRODCpwdrepl-Member|Denied RODC Password Replication Group" = {
      "member" = "Right-AD-Group-DeniedRODCpwdrepl-Member"
      "group"  = "Denied RODC Password Replication Group"
    }
    "Right-AD-Group-CertPublishers-Member|Cert Publishers" = {
      "member" = "Right-AD-Group-CertPublishers-Member"
      "group"  = "Cert Publishers"
    }
    "Right-AD-Group-DNSAdmins-Member|DnsAdmins" = {
      "member" = "Right-AD-Group-DNSAdmins-Member"
      "group"  = "DnsAdmins"
    }
    "Right-AD-Group-DNSUpdateProxy-Member|DnsUpdateProxy" = {
      "member" = "Right-AD-Group-DNSUpdateProxy-Member"
      "group"  = "DnsUpdateProxy"
    }
    "Right-AD-Group-EnterpriseKeyAdmins-Member|Enterprise Key Admins" = {
      "member" = "Right-AD-Group-EnterpriseKeyAdmins-Member"
      "group"  = "Enterprise Key Admins"
    }
    "Right-AD-Group-KeyAdmins-Member|Key Admins" = {
      "member" = "Right-AD-Group-KeyAdmins-Member"
      "group"  = "Key Admins"
    }
    "Right-AD-Group-ProtectedUsers-Member|Protected Users" = {
      "member" = "Right-AD-Group-ProtectedUsers-Member"
      "group"  = "Protected Users"
    }
    "Right-AD-Group-RASandIASservers-Member|RAS and IAS Servers" = {
      "member" = "Right-AD-Group-RASandIASservers-Member"
      "group"  = "RAS and IAS Servers"
    }
    "Role-AD-DomainAdmins|Right-AD-Group-DomainAdmins-Member" = {
      "member" = "Role-AD-DomainAdmins"
      "group"  = "Right-AD-Group-DomainAdmins-Member"
    }
    "Role-AD-EnterpriseAdmins|Right-AD-Group-EnterpriseAdmins-Member" = {
      "member" = "Role-AD-EnterpriseAdmins"
      "group"  = "Right-AD-Group-EnterpriseAdmins-Member"
    }
    "Role-AD-SchemaAdmins|Right-AD-Group-SchemaAdmins-Member" = {
      "member" = "Role-AD-SchemaAdmins"
      "group"  = "Right-AD-Group-SchemaAdmins-Member"
    }
    "Role-AD-FullAdmins|Right-AD-Group-DomainAdmins-Member" = {
      "member" = "Role-AD-FullAdmins"
      "group"  = "Right-AD-Group-DomainAdmins-Member"
    }
    "Role-AD-FullAdmins|Right-AD-Group-EnterpriseAdmins-Member" = {
      "member" = "Role-AD-FullAdmins"
      "group"  = "Right-AD-Group-EnterpriseAdmins-Member"
    }
    "Role-AD-FullAdmins|Right-AD-Group-SchemaAdmins-Member" = {
      "member" = "Role-AD-FullAdmins"
      "group"  = "Right-AD-Group-SchemaAdmins-Member"
    }
    "Role-AD-RBACOperator|Right-AD-Group-Roles-modifymembers" = {
      "member" = "Role-AD-RBACOperator"
      "group"  = "Right-AD-Group-Roles-modifymembers"
    }
    "Role-AD-ADOperator|Right-AD-Group-CertPublishers-Member" = {
      "member" = "Role-AD-ADOperator"
      "group"  = "Right-AD-Group-CertPublishers-Member"
    }
    "Role-AD-ADOperator|Right-AD-Group-DnsAdmins-Member" = {
      "member" = "Role-AD-ADOperator"
      "group"  = "Right-AD-Group-DnsAdmins-Member"
    }
    "Role-AD-ADOperator|Right-AD-Computer-Servers-CreMoDel" = {
      "member" = "Role-AD-ADOperator"
      "group"  = "Right-AD-Computer-Servers-CreMoDel"
    }
    "Role-AD-ADOperator|Right-AD-Computer-Workstations-CreMoDel" = {
      "member" = "Role-AD-ADOperator"
      "group"  = "Right-AD-Computer-Workstations-CreMoDel"
    }
    "Role-AD-ADOperator|Right-AD-Computer-Servers-windows-LAPSmodify" = {
      "member" = "Role-AD-ADOperator"
      "group"  = "Right-AD-Computer-Servers-windows-LAPSmodify"
    }
    "Role-AD-ADOperator|Right-AD-Computer-ComputersCN-CreMoDel" = {
      "member" = "Role-AD-ADOperator"
      "group"  = "Right-AD-Computer-ComputersCN-CreMoDel"
    }
    "Role-AD-ADOperator|Right-AD-Group-EndUser-CreMoDel" = {
      "member" = "Role-AD-ADOperator"
      "group"  = "Right-AD-Group-EndUser-CreMoDel"
    }
    "Role-AD-ADOperator|Right-AD-Group-Rights-CreMoDel" = {
      "member" = "Role-AD-ADOperator"
      "group"  = "Right-AD-Group-Rights-CreMoDel"
    }
    "Role-AD-ADOperator|Right-AD-Group-Roles-CreMoDel" = {
      "member" = "Role-AD-ADOperator"
      "group"  = "Right-AD-Group-Roles-CreMoDel"
    }
    "Role-AD-ADOperator|Right-AD-Users-CreMoDel" = {
      "member" = "Role-AD-ADOperator"
      "group"  = "Right-AD-Users-CreMoDel"
    }
    "Role-AD-DHCPServers|Right-AD-Group-DnsUpdateProxy-Member" = {
      "member" = "Role-AD-DHCPServers"
      "group"  = "Right-AD-Group-DnsUpdateProxy-Member"
    }
    "Role-AD-cadeploy|Right-AD-PKI-FullAccess" = {
      "member" = "Role-AD-cadeploy"
      "group"  = "Right-AD-PKI-FullAccess"
    }
    "Role-AD-cadeploy|Right-AD-Group-CertPublishers-Member" = {
      "member" = "Role-AD-cadeploy"
      "group"  = "Right-AD-Group-CertPublishers-Member"
    }
    "Role-AD-cadeploy|Right-DC-BuiltinGroup-BackupOperators" = {
      "member" = "Role-AD-cadeploy"
      "group"  = "Right-DC-BuiltinGroup-BackupOperators"
    }
  }

  access_rule_definitions = {
    "Right-AD-Computer-Servers-CreMoDel|0" = {
      "trustee"      = "Right-AD-Computer-Servers-CreMoDel"
      "target_alias" = "Computer-Servers"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Computer"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Computer-Servers-CreMoDel|1" = {
      "trustee"      = "Right-AD-Computer-Servers-CreMoDel"
      "target_alias" = "Computer-Servers"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Computer"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Computer-Servers-Windows-CreMoDel|0" = {
      "trustee"      = "Right-AD-Computer-Servers-Windows-CreMoDel"
      "target_alias" = "Computer-Servers-Win"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Computer"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Computer-Servers-Windows-CreMoDel|1" = {
      "trustee"      = "Right-AD-Computer-Servers-Windows-CreMoDel"
      "target_alias" = "Computer-Servers-Win"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Computer"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Computer-Servers-Windows-LAPSread|0" = {
      "trustee"      = "Right-AD-Computer-Servers-Windows-LAPSread"
      "target_alias" = "Computer-Servers-Win"
      "target_path"  = null
      "rights" = [
        "ReadProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "ms-Mcs-AdmPwd"
      "inherited_object_type" = "Computer"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Computer-Servers-Windows-LAPSmodify|0" = {
      "trustee"      = "Right-AD-Computer-Servers-Windows-LAPSmodify"
      "target_alias" = "Computer-Servers-Win"
      "target_path"  = null
      "rights" = [
        "ReadProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "ms-Mcs-AdmPwd"
      "inherited_object_type" = "Computer"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Computer-Servers-Windows-LAPSmodify|1" = {
      "trustee"      = "Right-AD-Computer-Servers-Windows-LAPSmodify"
      "target_alias" = "Computer-Servers-Win"
      "target_path"  = null
      "rights" = [
        "ReadProperty",
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "ms-Mcs-AdmPwdExpirationTime"
      "inherited_object_type" = "Computer"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Computer-Servers-Linux-CreMoDel|0" = {
      "trustee"      = "Right-AD-Computer-Servers-Linux-CreMoDel"
      "target_alias" = "Computer-Servers-Lin"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Computer"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Computer-Servers-Linux-CreMoDel|1" = {
      "trustee"      = "Right-AD-Computer-Servers-Linux-CreMoDel"
      "target_alias" = "Computer-Servers-Lin"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Computer"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Computer-Workstations-CreMoDel|0" = {
      "trustee"      = "Right-AD-Computer-Workstations-CreMoDel"
      "target_alias" = "Computer-Workstations"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Computer"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Computer-Workstations-CreMoDel|1" = {
      "trustee"      = "Right-AD-Computer-Workstations-CreMoDel"
      "target_alias" = "Computer-Workstations"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Computer"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Computer-ComputersCN-CreMoDel|0" = {
      "trustee"      = "Right-AD-Computer-ComputersCN-CreMoDel"
      "target_alias" = null
      "target_path"  = "CN=Computers"
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Computer"
      "inherited_object_type" = "All"
      "inheritance"           = "None"
    }
    "Right-AD-Computer-ComputersCN-CreMoDel|1" = {
      "trustee"      = "Right-AD-Computer-ComputersCN-CreMoDel"
      "target_alias" = null
      "target_path"  = "CN=Computers"
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Computer"
      "inheritance"           = "Children"
    }
    "Right-AD-Group-EndUser-CreMoDel|0" = {
      "trustee"      = "Right-AD-Group-EndUser-CreMoDel"
      "target_alias" = "Groups-EndUser"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Group"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-CreMoDel|1" = {
      "trustee"      = "Right-AD-Group-EndUser-CreMoDel"
      "target_alias" = "Groups-EndUser"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-ModifyMembers|0" = {
      "trustee"      = "Right-AD-Group-EndUser-ModifyMembers"
      "target_alias" = "Groups-EndUser"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "Member"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-App-CreMoDel|0" = {
      "trustee"      = "Right-AD-Group-EndUser-App-CreMoDel"
      "target_alias" = "Groups-EndUser-AppGroups"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Group"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-App-CreMoDel|1" = {
      "trustee"      = "Right-AD-Group-EndUser-App-CreMoDel"
      "target_alias" = "Groups-EndUser-AppGroups"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-App-ModifyMembers|0" = {
      "trustee"      = "Right-AD-Group-EndUser-App-ModifyMembers"
      "target_alias" = "Groups-EndUser-AppGroups"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "Member"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Project-CreMoDel|0" = {
      "trustee"      = "Right-AD-Group-EndUser-Project-CreMoDel"
      "target_alias" = "Groups-EndUser-ProjectGroups"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Group"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Project-CreMoDel|1" = {
      "trustee"      = "Right-AD-Group-EndUser-Project-CreMoDel"
      "target_alias" = "Groups-EndUser-ProjectGroups"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Project-ModifyMembers|0" = {
      "trustee"      = "Right-AD-Group-EndUser-Project-ModifyMembers"
      "target_alias" = "Groups-EndUser-ProjectGroups"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "Member"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Department-CreMoDel|0" = {
      "trustee"      = "Right-AD-Group-EndUser-Department-CreMoDel"
      "target_alias" = "Groups-EndUser-DepartmentGroups"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Group"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Department-CreMoDel|1" = {
      "trustee"      = "Right-AD-Group-EndUser-Department-CreMoDel"
      "target_alias" = "Groups-EndUser-DepartmentGroups"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Department-ModifyMembers|0" = {
      "trustee"      = "Right-AD-Group-EndUser-Department-ModifyMembers"
      "target_alias" = "Groups-EndUser-DepartmentGroups"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "Member"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Distribution-CreMoDel|0" = {
      "trustee"      = "Right-AD-Group-EndUser-Distribution-CreMoDel"
      "target_alias" = "Groups-EndUser-DistributionGroups"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Group"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Distribution-CreMoDel|1" = {
      "trustee"      = "Right-AD-Group-EndUser-Distribution-CreMoDel"
      "target_alias" = "Groups-EndUser-DistributionGroups"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Distribution-ModifyMembers|0" = {
      "trustee"      = "Right-AD-Group-EndUser-Distribution-ModifyMembers"
      "target_alias" = "Groups-EndUser-DistributionGroups"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "Member"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Cooperation-CreMoDel|0" = {
      "trustee"      = "Right-AD-Group-EndUser-Cooperation-CreMoDel"
      "target_alias" = "Groups-EndUser-CooperationGroups"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Group"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Cooperation-CreMoDel|1" = {
      "trustee"      = "Right-AD-Group-EndUser-Cooperation-CreMoDel"
      "target_alias" = "Groups-EndUser-CooperationGroups"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-EndUser-Cooperation-ModifyMembers|0" = {
      "trustee"      = "Right-AD-Group-EndUser-Cooperation-ModifyMembers"
      "target_alias" = "Groups-EndUser-CooperationGroups"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "Member"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-Rights-CreMoDel|0" = {
      "trustee"      = "Right-AD-Group-Rights-CreMoDel"
      "target_alias" = "Rights-Root"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Group"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-Rights-CreMoDel|1" = {
      "trustee"      = "Right-AD-Group-Rights-CreMoDel"
      "target_alias" = "Rights-Root"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-Rights-ModifyMembers|0" = {
      "trustee"      = "Right-AD-Group-Rights-ModifyMembers"
      "target_alias" = "Rights-Root"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "Member"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-Roles-CreMoDel|0" = {
      "trustee"      = "Right-AD-Group-Roles-CreMoDel"
      "target_alias" = "Roles-Root"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "Group"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-Roles-CreMoDel|1" = {
      "trustee"      = "Right-AD-Group-Roles-CreMoDel"
      "target_alias" = "Roles-Root"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Group-Roles-ModifyMembers|0" = {
      "trustee"      = "Right-AD-Group-Roles-ModifyMembers"
      "target_alias" = "Roles-Root"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "Member"
      "inherited_object_type" = "Group"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Users-CreMoDel|0" = {
      "trustee"      = "Right-AD-Users-CreMoDel"
      "target_alias" = "Users"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "User"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Users-CreMoDel|1" = {
      "trustee"      = "Right-AD-Users-CreMoDel"
      "target_alias" = "Users"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "User"
      "inherited_object_type" = "User"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Users-AdmUsers-CreMoDel|0" = {
      "trustee"      = "Right-AD-Users-AdmUsers-CreMoDel"
      "target_alias" = "Users-AdmUsers"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "User"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Users-AdmUsers-CreMoDel|1" = {
      "trustee"      = "Right-AD-Users-AdmUsers-CreMoDel"
      "target_alias" = "Users-AdmUsers"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "User"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Users-EndUsers-CreMoDel|0" = {
      "trustee"      = "Right-AD-Users-EndUsers-CreMoDel"
      "target_alias" = "Users-EndUsers"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "User"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Users-EndUsers-CreMoDel|1" = {
      "trustee"      = "Right-AD-Users-EndUsers-CreMoDel"
      "target_alias" = "Users-EndUsers"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "User"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Users-SvcUsers-CreMoDel|0" = {
      "trustee"      = "Right-AD-Users-SvcUsers-CreMoDel"
      "target_alias" = "Users-SvcUsers"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "User"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Users-SvcUsers-CreMoDel|1" = {
      "trustee"      = "Right-AD-Users-SvcUsers-CreMoDel"
      "target_alias" = "Users-SvcUsers"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "User"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Users-MsaUsers-CreMoDel|0" = {
      "trustee"      = "Right-AD-Users-MsaUsers-CreMoDel"
      "target_alias" = "Users-MsaUsers"
      "target_path"  = null
      "rights" = [
        "CreateChild",
        "DeleteChild"
      ]
      "access"                = "Allow"
      "object_type"           = "User"
      "inherited_object_type" = "organizationalUnit"
      "inheritance"           = "Descendents"
    }
    "Right-AD-Users-MsaUsers-CreMoDel|1" = {
      "trustee"      = "Right-AD-Users-MsaUsers-CreMoDel"
      "target_alias" = "Users-MsaUsers"
      "target_path"  = null
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "All"
      "inherited_object_type" = "User"
      "inheritance"           = "Descendents"
    }
    "Right-AD-PKI-FullAccess|0" = {
      "trustee"      = "Right-AD-PKI-FullAccess"
      "target_alias" = null
      "target_path"  = "CN=Public Key Services,CN=Services,CN=Configuration"
      "rights" = [
        "GenericAll"
      ]
      "access"                = "Allow"
      "object_type"           = null
      "inherited_object_type" = null
      "inheritance"           = "All"
    }
    "Right-AD-PKI-FullAccess|1" = {
      "trustee"      = "Right-AD-PKI-FullAccess"
      "target_alias" = null
      "target_path"  = "CN=Cert Publishers,CN=Users"
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "Member"
      "inherited_object_type" = null
      "inheritance"           = "None"
    }
    "Right-AD-PKI-FullAccess|2" = {
      "trustee"      = "Right-AD-PKI-FullAccess"
      "target_alias" = null
      "target_path"  = "CN=Pre-Windows 2000 Compatible Access,CN=Builtin"
      "rights" = [
        "WriteProperty"
      ]
      "access"                = "Allow"
      "object_type"           = "Member"
      "inherited_object_type" = null
      "inheritance"           = "None"
    }
  }

  gpo_definitions = {
    "DC - RoleGPO - v0r12" = {
      "source_name" = "DC - RoleGPO - v0r12"
      "target_name" = "DC - RoleGPO - v0r12"
    }
    "DOMAIN - Domain Policy - v0r2" = {
      "source_name" = "DOMAIN - Domain Policy - v0r2"
      "target_name" = "${data.adlc_domain.current.netbios_name} - Domain Policy - v0r2"
    }
    "DoD Windows 11 Computer STIG v1r2" = {
      "source_name" = "DoD Windows 11 Computer STIG v1r2"
      "target_name" = "DoD Windows 11 Computer STIG v1r2"
    }
    "DoD Windows 11 User STIG v1r2" = {
      "source_name" = "DoD Windows 11 User STIG v1r2"
      "target_name" = "DoD Windows 11 User STIG v1r2"
    }
    "DoD Microsoft Defender Antivirus STIG Computer v2r4" = {
      "source_name" = "DoD Microsoft Defender Antivirus STIG Computer v2r4"
      "target_name" = "DoD Microsoft Defender Antivirus STIG Computer v2r4"
    }
    "DoD Windows Firewall STIG v1r7" = {
      "source_name" = "DoD Windows Firewall STIG v1r7"
      "target_name" = "DoD Windows Firewall STIG v1r7"
    }
    "DoD WinSvr 2022 DC STIG Comp v1r1" = {
      "source_name" = "DoD WinSvr 2022 DC STIG Comp v1r1"
      "target_name" = "DoD WinSvr 2022 DC STIG Comp v1r1"
    }
    "DoD WinSvr 2022 MS STIG Comp v1r1" = {
      "source_name" = "DoD WinSvr 2022 MS STIG Comp v1r1"
      "target_name" = "DoD WinSvr 2022 MS STIG Comp v1r1"
    }
    "DoD Google Chrome STIG Computer v2r7" = {
      "source_name" = "DoD Google Chrome STIG Computer v2r7"
      "target_name" = "DoD Google Chrome STIG Computer v2r7"
    }
    "DoD Microsoft Edge STIG Computer v1r6" = {
      "source_name" = "DoD Microsoft Edge STIG Computer v1r6"
      "target_name" = "DoD Microsoft Edge STIG Computer v1r6"
    }
    "Domain - Windows Server Baseline - 2022 Schannel Hardening - v0r7" = {
      "source_name" = "Domain - Windows Server Baseline - 2022 Schannel Hardening - v0r7"
      "target_name" = "${data.adlc_domain.current.netbios_name} - Windows Server Baseline - 2022 Schannel Hardening - v0r7"
    }
    "Domain - Windows Server Baseline - 2019 Schannel Hardening - v0r7" = {
      "source_name" = "Domain - Windows Server Baseline - 2019 Schannel Hardening - v0r7"
      "target_name" = "${data.adlc_domain.current.netbios_name} - Windows Server Baseline - 2019 Schannel Hardening - v0r7"
    }
    "Domain - Windows Server Baseline - Delta Policy - v0r9" = {
      "source_name" = "Domain - Windows Server Baseline - Delta Policy - v0r9"
      "target_name" = "${data.adlc_domain.current.netbios_name} - Windows Server Baseline - Delta Policy - v0r9"
    }
    "Domain - Windows Workstation Baseline - Schannel Hardening - v0r5" = {
      "source_name" = "Domain - Windows Workstation Baseline - Schannel Hardening - v0r5"
      "target_name" = "${data.adlc_domain.current.netbios_name} - Windows Workstation Baseline - Schannel Hardening - v0r5"
    }
    "Domain - Windows Workstation Baseline - Delta Policy - v0r8" = {
      "source_name" = "Domain - Windows Workstation Baseline - Delta Policy - v0r8"
      "target_name" = "${data.adlc_domain.current.netbios_name} - Windows Workstation Baseline - Delta Policy - v0r8"
    }
  }

  gpo_link_definitions = {
    "DomainRoot" = {
      "target_alias" = "DomainRoot"
      "links" = [
        {
          "gpo"      = "${data.adlc_domain.current.netbios_name} - Domain Policy - v0r2"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "Default Domain Policy"
          "enabled"  = true
          "enforced" = false
        }
      ]
    }
    "DomainControllers" = {
      "target_alias" = "DomainControllers"
      "links" = [
        {
          "gpo"      = "DC - RoleGPO - v0r12"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "${data.adlc_domain.current.netbios_name} - Windows Server Baseline - Delta Policy - v0r9"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD WinSvr 2022 DC STIG Comp v1r1"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD WinSvr 2022 MS STIG Comp v1r1"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD Microsoft Defender Antivirus STIG Computer v2r4"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD Windows Firewall STIG v1r7"
          "enabled"  = true
          "enforced" = false
        }
      ]
    }
    "Computer-Servers-Win" = {
      "target_alias" = "Computer-Servers-Win"
      "links" = [
        {
          "gpo"      = "${data.adlc_domain.current.netbios_name} - Windows Server Baseline - Delta Policy - v0r9"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "${data.adlc_domain.current.netbios_name} - Windows Server Baseline - 2019 Schannel Hardening - v0r7"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "${data.adlc_domain.current.netbios_name} - Windows Server Baseline - 2022 Schannel Hardening - v0r7"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD WinSvr 2022 MS STIG Comp v1r1"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD Microsoft Defender Antivirus STIG Computer v2r4"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD Windows Firewall STIG v1r7"
          "enabled"  = true
          "enforced" = false
        }
      ]
    }
    "Computer-Workstations-Win" = {
      "target_alias" = "Computer-Workstations-Win"
      "links" = [
        {
          "gpo"      = "${data.adlc_domain.current.netbios_name} - Windows Workstation Baseline - Delta Policy - v0r8"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD Windows 11 Computer STIG v1r2"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD Windows 11 User STIG v1r2"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD Microsoft Defender Antivirus STIG Computer v2r4"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD Windows Firewall STIG v1r7"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD Google Chrome STIG Computer v2r7"
          "enabled"  = true
          "enforced" = false
        },
        {
          "gpo"      = "DoD Microsoft Edge STIG Computer v1r6"
          "enabled"  = true
          "enforced" = false
        }
      ]
    }
  }

  wmi_filter_definitions = {
    "Windows 10-11" = {
      "name"        = "Windows 10-11"
      "description" = "Windows 10-11"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE Version LIKE \"10.0.%\" and ProductType = \"1\"",
        "Select * from Win32_OperatingSystem WHERE Version LIKE \"11.0.%\" and ProductType = \"1\""
      ]
      "links" = [
        "DoD Windows 11 Computer STIG v1r2"
      ]
    }
    "Windows Server 2019-22" = {
      "name"        = "Windows Server 2019-22"
      "description" = "Windows Server 2019-22"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE (ProductType = \"2\" or ProductType = \"3\")",
        "Select * from Win32_OperatingSystem WHERE (Caption LIKE \"%2019%\" or Caption LIKE \"%2022%\")"
      ]
      "links" = [
        "DoD WinSvr 2022 MS STIG Comp v1r1",
        "DoD WinSvr 2022 DC STIG Comp v1r1"
      ]
    }
    "Windows Server 2022" = {
      "name"        = "Windows Server 2022"
      "description" = "Windows Server 2022"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE ((ProductType = \"2\" or ProductType = \"3\") and (Caption LIKE \"%2022%\"))"
      ]
      "links" = [
        "${data.adlc_domain.current.netbios_name} - Windows Server Baseline - 2022 Schannel Hardening - v0r7"
      ]
    }
    "Windows Server 2019" = {
      "name"        = "Windows Server 2019"
      "description" = "Windows Server 2019"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE ((ProductType = \"2\" or ProductType = \"3\") and (Caption LIKE \"%2019%\"))"
      ]
      "links" = [
        "${data.adlc_domain.current.netbios_name} - Windows Server Baseline - 2019 Schannel Hardening - v0r7"
      ]
    }
    "Windows Server 2019-22 Domain Member (${data.adlc_domain.current.dns_root})" = {
      "name"        = "Windows Server 2019-22 Domain Member (${data.adlc_domain.current.dns_root})"
      "description" = "Windows Server 2019-22 Domain Member (${data.adlc_domain.current.dns_root})"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE ProductType = \"3\"",
        "Select * from Win32_OperatingSystem WHERE (Caption LIKE \"%2019%\" OR Caption LIKE \"%2022%\")"
      ]
      "links" = []
    }
    "Windows Server 2019-22 Domain Controller" = {
      "name"        = "Windows Server 2019-22 Domain Controller"
      "description" = "Windows Server 2019-22 Domain Controller"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE ProductType = \"2\"",
        "Select * from Win32_OperatingSystem WHERE (Caption LIKE \"%2019%\" OR Caption LIKE \"%2022%\")"
      ]
      "links" = [
        "DoD WinSvr 2022 DC STIG Comp v1r1"
      ]
    }
    "Windows Server 2016" = {
      "name"        = "Windows Server 2016"
      "description" = "Windows Server 2016"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE (ProductType = \"2\" or ProductType = \"3\")",
        "Select * from Win32_OperatingSystem WHERE Caption LIKE \"%2016%\""
      ]
      "links" = []
    }
    "Windows Server 2016 Domain Member" = {
      "name"        = "Windows Server 2016 Domain Member"
      "description" = "Windows Server 2016 Domain Member"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE Version LIKE \"10.0%\" AND ProductType = \"3\"",
        "Select * from Win32_OperatingSystem WHERE Caption LIKE \"%2016%\""
      ]
      "links" = []
    }
    "Windows Server 2016 Domain Controller" = {
      "name"        = "Windows Server 2016 Domain Controller"
      "description" = "Windows Server 2016 Domain Controller"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE Version LIKE \"10.0%\" AND ProductType = \"2\"",
        "Select * from Win32_OperatingSystem WHERE Caption LIKE \"%2016%\""
      ]
      "links" = []
    }
    "Windows Server 2012 R2" = {
      "name"        = "Windows Server 2012 R2"
      "description" = "Windows Server 2012 R2"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE Version LIKE \"6.3.%\" AND (ProductType = \"2\" or ProductType = \"3\")"
      ]
      "links" = []
    }
    "Windows Server 2012 R2 Domain Member" = {
      "name"        = "Windows Server 2012 R2 Domain Member"
      "description" = "Windows Server 2012 R2 Domain Member"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE Version LIKE \"6.3.%\" AND ProductType = \"3\""
      ]
      "links" = []
    }
    "Windows Server 2012 R2 Domain Controller" = {
      "name"        = "Windows Server 2012 R2 Domain Controller"
      "description" = "Windows Server 2012 R2 Domain Controller"
      "queries" = [
        "Select * from Win32_OperatingSystem WHERE Version LIKE \"6.3.%\" AND ProductType = \"2\"",
        "SELECT * FROM Win32_ServerFeature WHERE Name='Active Directory Domain Services'"
      ]
      "links" = []
    }
    "Microsoft Office Access 2016" = {
      "name"        = "Microsoft Office Access 2016"
      "description" = "Access 2016"
      "queries" = [
        "SELECT Name,Version FROM CIM_Datafile WHERE (Name = 'C:\\\\Program Files (x86)\\\\Microsoft Office\\\\Office16\\\\msaccess.exe' AND Version LIKE \"16.%\") OR (Name = 'C:\\\\Program Files\\\\Microsoft Office\\\\Office16\\\\msaccess.exe' AND Version LIKE \"16.%\")"
      ]
      "links" = []
    }
    "Microsoft Office Excel 2016" = {
      "name"        = "Microsoft Office Excel 2016"
      "description" = "Microsoft Office Excel 2016"
      "queries" = [
        "SELECT Name,Version FROM CIM_Datafile WHERE (Name = 'C:\\\\Program Files (x86)\\\\Microsoft Office\\\\Office16\\\\excel.exe' AND Version LIKE \"16.%\") OR (Name = 'C:\\\\Program Files\\\\Microsoft Office\\\\Office16\\\\excel.exe' AND Version LIKE \"16.%\")"
      ]
      "links" = []
    }
    "Microsoft Office 2016" = {
      "name"        = "Microsoft Office 2016"
      "description" = "Microsoft Office 2016"
      "queries" = [
        "SELECT Name,Version FROM CIM_Datafile WHERE (Name = 'C:\\\\Program Files (x86)\\\\Microsoft Office\\\\Office 16\\\\clview.exe' AND Version LIKE \"16.%\") OR (Name = 'C:\\\\Program Files\\\\Microsoft Office\\\\Office 16\\\\clview.exe' AND Version LIKE \"16.%\")"
      ]
      "links" = []
    }
    "Microsoft Office OneDrive for Business 2016" = {
      "name"        = "Microsoft Office OneDrive for Business 2016"
      "description" = "Microsoft Office OneDrive for Business 2016"
      "queries" = [
        "SELECT Name,Version FROM CIM_Datafile WHERE (Name = 'C:\\\\Program Files (x86)\\\\Microsoft Office\\\\Office16\\\\groove.exe' AND Version LIKE \"16.%\") OR (Name = 'C:\\\\Program Files\\\\Microsoft Office\\\\Office16\\\\groove.exe' AND Version LIKE \"16.%\")"
      ]
      "links" = []
    }
    "Microsoft Office Outlook 2016" = {
      "name"        = "Microsoft Office Outlook 2016"
      "description" = "Microsoft Office Outlook 2016"
      "queries" = [
        "SELECT Name,Version FROM CIM_Datafile WHERE (Name = 'C:\\\\Program Files (x86)\\\\Microsoft Office\\\\Office16\\\\outlook.exe' AND Version LIKE \"16.%\") OR (Name = 'C:\\\\Program Files\\\\Microsoft Office\\\\Office16\\\\outlook.exe' AND Version LIKE \"16.%\")"
      ]
      "links" = []
    }
    "Microsoft Office PowerPoint 2016" = {
      "name"        = "Microsoft Office PowerPoint 2016"
      "description" = "Microsoft Office PowerPoint 2016"
      "queries" = [
        "SELECT Name,Version FROM CIM_Datafile WHERE (Name = 'C:\\\\Program Files (x86)\\\\Microsoft Office\\\\Office16\\\\powerpnt.exe' AND Version LIKE \"16.%\") OR (Name = 'C:\\\\Program Files\\\\Microsoft Office\\\\Office16\\\\powerpnt.exe' AND Version LIKE \"16.%\")"
      ]
      "links" = []
    }
    "Microsoft Office Project 2016" = {
      "name"        = "Microsoft Office Project 2016"
      "description" = "Microsoft Office Project 2016"
      "queries" = [
        "SELECT Name,Version FROM CIM_Datafile WHERE (Name = 'C:\\\\Program Files (x86)\\\\Microsoft Office\\\\Office16\\\\winproj.exe' AND Version LIKE \"16.%\") OR (Name = 'C:\\\\Program Files\\\\Microsoft Office\\\\Office16\\\\winproj.exe' AND Version LIKE \"16.%\")"
      ]
      "links" = []
    }
    "Microsoft Office Publisher 2016" = {
      "name"        = "Microsoft Office Publisher 2016"
      "description" = "Microsoft Office Publisher 2016"
      "queries" = [
        "SELECT Name,Version FROM CIM_Datafile WHERE (Name = 'C:\\\\Program Files (x86)\\\\Microsoft Office\\\\Office16\\\\mspub.exe' AND Version LIKE \"16.%\") OR (Name = 'C:\\\\Program Files\\\\Microsoft Office\\\\Office16\\\\mspub.exe' AND Version LIKE \"16.%\")"
      ]
      "links" = []
    }
    "Microsoft Office Skype for Business 2016" = {
      "name"        = "Microsoft Office Skype for Business 2016"
      "description" = "Microsoft Office Skype for Business 2016"
      "queries" = [
        "SELECT Name,Version FROM CIM_Datafile WHERE (Name = 'C:\\\\Program Files (x86)\\\\Microsoft Office\\\\Office16\\\\lync.exe' AND Version LIKE \"16.%\") OR (Name = 'C:\\\\Program Files\\\\Microsoft Office\\\\Office16\\\\lync.exe' AND Version LIKE \"16.%\")"
      ]
      "links" = []
    }
    "Microsoft Office Visio 2016" = {
      "name"        = "Microsoft Office Visio 2016"
      "description" = "Microsoft Office Visio 2016"
      "queries" = [
        "SELECT Name,Version FROM CIM_Datafile WHERE (Name = 'C:\\\\Program Files (x86)\\\\Microsoft Office\\\\Office16\\\\visio.exe' AND Version LIKE \"16.%\") OR (Name = 'C:\\\\Program Files\\\\Microsoft Office\\\\Office16\\\\visio.exe' AND Version LIKE \"16.%\")"
      ]
      "links" = []
    }
    "Microsoft Office Word 2016" = {
      "name"        = "Microsoft Office Word 2016"
      "description" = "Microsoft Office Word 2016"
      "queries" = [
        "SELECT Name,Version FROM CIM_Datafile WHERE (Name = 'C:\\\\Program Files (x86)\\\\Microsoft Office\\\\Office16\\\\winword.exe' AND Version LIKE \"16.%\") OR (Name = 'C:\\\\Program Files\\\\Microsoft Office\\\\Office16\\\\winword.exe' AND Version LIKE \"16.%\")"
      ]
      "links" = []
    }
    "Computers in site ${var.ad_site_name}" = {
      "name"        = "Computers in site ${var.ad_site_name}"
      "description" = "Computers in site ${var.ad_site_name}"
      "queries" = [
        "Select * from Win32_NTDomain where DomainName = \"${data.adlc_domain.current.dns_root}\" AND ClientSiteName = \"${var.ad_site_name}\""
      ]
      "links" = []
    }
  }

  wmi_filter_links = {
    "Windows 10-11|DoD Windows 11 Computer STIG v1r2" = {
      "filter" = "Windows 10-11"
      "gpo"    = "DoD Windows 11 Computer STIG v1r2"
    }
    "Windows Server 2019-22|DoD WinSvr 2022 MS STIG Comp v1r1" = {
      "filter" = "Windows Server 2019-22"
      "gpo"    = "DoD WinSvr 2022 MS STIG Comp v1r1"
    }
    "Windows Server 2019-22|DoD WinSvr 2022 DC STIG Comp v1r1" = {
      "filter" = "Windows Server 2019-22"
      "gpo"    = "DoD WinSvr 2022 DC STIG Comp v1r1"
    }
    "Windows Server 2022|${data.adlc_domain.current.netbios_name} - Windows Server Baseline - 2022 Schannel Hardening - v0r7" = {
      "filter" = "Windows Server 2022"
      "gpo"    = "${data.adlc_domain.current.netbios_name} - Windows Server Baseline - 2022 Schannel Hardening - v0r7"
    }
    "Windows Server 2019|${data.adlc_domain.current.netbios_name} - Windows Server Baseline - 2019 Schannel Hardening - v0r7" = {
      "filter" = "Windows Server 2019"
      "gpo"    = "${data.adlc_domain.current.netbios_name} - Windows Server Baseline - 2019 Schannel Hardening - v0r7"
    }
    "Windows Server 2019-22 Domain Controller|DoD WinSvr 2022 DC STIG Comp v1r1" = {
      "filter" = "Windows Server 2019-22 Domain Controller"
      "gpo"    = "DoD WinSvr 2022 DC STIG Comp v1r1"
    }
  }
}

resource "adlc_site" "reference" {
  count       = var.enable_site ? 1 : 0
  name        = var.ad_site_name
  description = "Site named by the original ADSite variable"
}

resource "adlc_subnet" "reference" {
  for_each = var.enable_site ? var.site_subnets : {}
  name     = each.key
  site     = adlc_site.reference[0].name
  location = each.value
}

resource "adlc_organizational_unit" "ou" {
  for_each    = var.enable_directory_objects ? local.ou_definitions : {}
  path        = each.value.path
  description = each.value.description
}

resource "adlc_group" "group" {
  for_each = var.enable_directory_objects ? local.group_definitions : {}

  depends_on = [adlc_organizational_unit.ou]

  name             = each.value.name
  sam_account_name = length(each.value.name) <= 20 ? each.value.name : "adlc-${substr(md5(each.value.name), 0, 14)}"
  path             = local.ou_definitions[each.value.alias].path
  description      = each.value.description
  scope            = each.value.scope
}

resource "adlc_group_member" "nested" {
  for_each = var.enable_directory_objects ? local.group_memberships : {}

  group  = contains(keys(local.group_definitions), each.value.group) ? adlc_group.group[each.value.group].distinguished_name : each.value.group
  member = adlc_group.group[each.value.member].distinguished_name
}

resource "adlc_access_rule" "reference" {
  for_each = var.enable_access_rules ? local.access_rule_definitions : {}

  depends_on = [adlc_organizational_unit.ou, adlc_group.group]

  target = each.value.target_alias == "DomainRoot" ? data.adlc_domain.current.distinguished_name : (
    each.value.target_alias != null ? local.ou_definitions[each.value.target_alias].path : each.value.target_path
  )
  trustee               = adlc_group.group[each.value.trustee].distinguished_name
  rights                = toset(each.value.rights)
  access                = each.value.access
  object_type           = each.value.object_type
  inherited_object_type = each.value.inherited_object_type
  inheritance           = each.value.inheritance
}

resource "adlc_json_gpo" "reference" {
  for_each = var.enable_gpo_imports ? local.gpo_definitions : {}

  path        = "${path.module}/gpo_imports/${each.value.source_name}.json"
  target_name = each.value.target_name
  replacements = {
    DomainFQDN = data.adlc_domain.current.dns_root
    DomainNB   = data.adlc_domain.current.netbios_name
  }
}

resource "adlc_gpo_links" "reference" {
  for_each = var.enable_gpo_links ? local.gpo_link_definitions : {}

  depends_on = [adlc_json_gpo.reference]

  target = each.value.target_alias == "DomainRoot" ? data.adlc_domain.current.distinguished_name : (
    each.value.target_alias == "DomainControllers" ? data.adlc_domain.current.domain_controllers_container : local.ou_definitions[each.value.target_alias].path
  )
  links = each.value.links
}

resource "adlc_wmi_filter" "reference" {
  for_each = var.enable_wmi_filters ? local.wmi_filter_definitions : {}

  name        = each.value.name
  description = each.value.description
  queries     = [for query in each.value.queries : { namespace = "root\\CIMv2", query = query }]
}

resource "adlc_gpo_wmi_filter" "reference" {
  for_each = var.enable_gpo_imports && var.enable_wmi_filter_links ? local.wmi_filter_links : {}

  gpo        = adlc_json_gpo.reference[each.value.gpo].target_name
  wmi_filter = adlc_wmi_filter.reference[each.value.filter].name
}

resource "adlc_netlogon_files" "reference" {
  count       = var.enable_netlogon_files ? 1 : 0
  source_path = "${path.module}/netlogon"
}
