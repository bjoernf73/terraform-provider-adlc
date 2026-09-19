# AD subnet helpers. Requires common.ps1.

function Get-ADSubnetOrNull([string]$Identity) {
    $serverParams = Get-ServerParams
    try {
        return Get-ADReplicationSubnet -Identity $Identity -Properties Description, Location, Site, DistinguishedName, Name @serverParams -ErrorAction Stop
    }
    catch {
        if (Test-IsIdentityNotFound $_) { return $null }
        throw
    }
}

function Get-ADSubnetResult($Subnet) {
    if ($null -eq $Subnet) {
        return [pscustomobject]@{ exists = $false }
    }
    $site = Get-ADSiteOrNull ([string]$Subnet.Site)
    return [pscustomobject]@{
        exists             = $true
        name               = [string]$Subnet.Name
        site_name          = [string]$site.Name
        description        = [string]$Subnet.Description
        location           = [string]$Subnet.Location
        distinguished_name = [string]$Subnet.DistinguishedName
    }
}
