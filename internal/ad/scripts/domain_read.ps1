$serverParams = Get-ServerParams
$domain = Get-ADDomain @serverParams -ErrorAction Stop

[pscustomobject]@{
    distinguished_name           = [string]$domain.DistinguishedName
    dns_root                     = [string]$domain.DNSRoot
    netbios_name                 = [string]$domain.NetBIOSName
    sid                          = [string]$domain.DomainSID
    domain_mode                  = [string]$domain.DomainMode
    forest                       = [string]$domain.Forest
    users_container              = [string]$domain.UsersContainer
    computers_container          = [string]$domain.ComputersContainer
    domain_controllers_container = [string]$domain.DomainControllersContainer
    pdc_emulator                 = [string]$domain.PDCEmulator
    infrastructure_master        = [string]$domain.InfrastructureMaster
} | ConvertTo-Json -Compress
