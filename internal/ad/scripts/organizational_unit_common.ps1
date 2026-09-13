# Shared helpers injected ahead of every organizational unit operation.
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory -ErrorAction Stop

function Get-ServerParams {
    $serverParams = @{}
    if ($null -ne $payload.domain_controller -and -not [string]::IsNullOrWhiteSpace([string]$payload.domain_controller)) {
        $serverParams['Server'] = [string]$payload.domain_controller
    }
    return $serverParams
}

function Get-DomainDN {
    $serverParams = Get-ServerParams
    return (Get-ADDomain @serverParams -ErrorAction Stop).DistinguishedName
}

function Convert-PathToDN([string]$Path, [string]$DomainDN) {
    $segments = @($Path -split '/' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ($segments.Count -eq 0) {
        throw 'path must contain at least one OU segment'
    }

    [array]::Reverse($segments)
    $ouParts = $segments | ForEach-Object { 'OU=' + $_ }
    return ($ouParts -join ',') + ',' + $DomainDN
}

function Convert-DNToPath([string]$DistinguishedName, [string]$DomainDN) {
    $relativeDN = $DistinguishedName
    if ($relativeDN.EndsWith(',' + $DomainDN)) {
        $relativeDN = $relativeDN.Substring(0, $relativeDN.Length - ($DomainDN.Length + 1))
    }

    $segments = @($relativeDN -split ',' | ForEach-Object {
        if ($_.StartsWith('OU=')) {
            $_.Substring(3)
        }
        else {
            $_
        }
    })

    [array]::Reverse($segments)
    return ($segments -join '/')
}

function Test-IsIdentityNotFound([System.Management.Automation.ErrorRecord]$ErrorRecord) {
    if ($null -eq $ErrorRecord) {
        return $false
    }

    if ($ErrorRecord.CategoryInfo.Reason -eq 'ADIdentityNotFoundException') {
        return $true
    }

    if ($null -ne $ErrorRecord.Exception -and $ErrorRecord.Exception.Message -match 'Cannot find an object with identity') {
        return $true
    }

    return $false
}

function Get-LeafOrganizationalUnit([string]$DistinguishedName) {
    $serverParams = Get-ServerParams
    return Get-ADOrganizationalUnit -Identity $DistinguishedName -Properties Description, DistinguishedName, Name @serverParams -ErrorAction Stop
}
