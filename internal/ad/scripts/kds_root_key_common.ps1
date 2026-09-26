# KDS root key helpers. Requires common.ps1.
#
# The Kds cmdlets (Get-KdsRootKey, Add-KdsRootKey) operate on the forest through the local
# domain controller and do not accept -Server, so Get-ServerParams is intentionally not used
# here.

function Get-KdsRootKeys {
    return @(Get-KdsRootKey -ErrorAction Stop)
}

function Get-KdsResult($Key) {
    return [pscustomobject]@{
        exists         = $true
        key_id         = $Key.KeyId.ToString()
        effective_time = $Key.EffectiveTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        creation_time  = $Key.CreationTime.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }
}

# Chooses which existing key the resource adopts: the newest key that is already effective,
# falling back to the newest key overall when none have taken effect yet.
function Select-KdsRootKey($Keys) {
    $sorted = @($Keys | Sort-Object EffectiveTime -Descending)
    if ($sorted.Count -eq 0) {
        return $null
    }

    $now = (Get-Date)
    $effective = $sorted | Where-Object { $_.EffectiveTime -le $now } | Select-Object -First 1
    if ($null -ne $effective) {
        return $effective
    }

    return $sorted[0]
}

# Forces every other domain controller in the forest to replicate the root key object from the
# DC that created it. KDS root keys live in the forest-wide Configuration partition, so this
# pushes the key to the whole forest at once instead of waiting for normal replication. The
# source is the DC this session is bound to, which is where Add-KdsRootKey wrote the object.
function Invoke-KdsRootKeyReplication($Key) {
    $rootDSE = Get-ADRootDSE -ErrorAction Stop
    $configNC = [string]$rootDSE.configurationNamingContext
    $sourceDC = [string]$rootDSE.dnsHostName
    $keyDN = "CN=$($Key.KeyId),CN=Master Root Keys,CN=Group Key Distribution Service,CN=Services,$configNC"

    $forest = Get-ADForest -ErrorAction Stop
    $destinations = New-Object System.Collections.Generic.List[string]
    foreach ($domain in $forest.Domains) {
        foreach ($dc in @(Get-ADDomainController -Filter * -Server $domain -ErrorAction Stop)) {
            $hostName = [string]$dc.HostName
            if ($hostName -ine $sourceDC -and -not $destinations.Contains($hostName)) {
                $destinations.Add($hostName)
            }
        }
    }

    $failures = New-Object System.Collections.Generic.List[string]
    foreach ($dest in $destinations) {
        try {
            Sync-ADObject -Object $keyDN -Source $sourceDC -Destination $dest -ErrorAction Stop
        }
        catch {
            $failures.Add("$dest ($($_.Exception.Message))")
        }
    }

    if ($failures.Count -gt 0) {
        throw "forced replication of the KDS root key from '$sourceDC' failed for: $($failures -join '; ')"
    }

    return @($destinations)
}
