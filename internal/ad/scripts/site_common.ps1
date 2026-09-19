# AD Site helpers. Requires common.ps1.

function Get-ADSiteOrNull([string]$Identity) {
    $serverParams = Get-ServerParams
    try {
        return Get-ADReplicationSite -Identity $Identity -Properties Description, Location, DistinguishedName, Name @serverParams -ErrorAction Stop
    }
    catch {
        if (Test-IsIdentityNotFound $_) { return $null }
        throw
    }
}

function Get-ADSiteResult($Site) {
    if ($null -eq $Site) {
        return [pscustomobject]@{ exists = $false }
    }
    return [pscustomobject]@{
        exists             = $true
        name               = [string]$Site.Name
        description        = [string]$Site.Description
        location           = [string]$Site.Location
        distinguished_name = [string]$Site.DistinguishedName
    }
}

function Set-ADTopologyTextProperties([string]$DistinguishedName, [string]$Description, [string]$Location) {
    $serverParams = Get-ServerParams
    Set-ADObject -Identity $DistinguishedName -Clear @('description', 'location') @serverParams -ErrorAction Stop

    $replace = @{}
    if (-not [string]::IsNullOrWhiteSpace($Description)) { $replace.description = $Description }
    if (-not [string]::IsNullOrWhiteSpace($Location)) { $replace.location = $Location }
    if ($replace.Count -gt 0) {
        Set-ADObject -Identity $DistinguishedName -Replace $replace @serverParams -ErrorAction Stop
    }
}
