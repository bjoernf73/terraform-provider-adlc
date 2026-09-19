# WMI filter helpers. Requires common.ps1.

function Get-WmiFilterContainerDN {
    return "CN=SOM,CN=WMIPolicy,CN=System,$(Get-DomainDN)"
}

function Get-WmiFilterByName([string]$Name) {
    $serverParams = Get-ServerParams
    $escaped = ConvertTo-LDAPFilterValue $Name
    $results = @(Get-ADObject -SearchBase (Get-WmiFilterContainerDN) -LDAPFilter "(&(objectClass=msWMI-Som)(msWMI-Name=$escaped))" -Properties 'msWMI-Name', 'msWMI-Parm1', 'msWMI-Parm2', 'msWMI-ID' @serverParams -ErrorAction Stop)
    if ($results.Count -gt 0) {
        return $results[0]
    }
    return $null
}

function Get-WmiFilterByGuid([string]$Guid) {
    $serverParams = Get-ServerParams
    $escaped = ConvertTo-LDAPFilterValue "{$Guid}"
    $results = @(Get-ADObject -SearchBase (Get-WmiFilterContainerDN) -LDAPFilter "(&(objectClass=msWMI-Som)(msWMI-ID=$escaped))" -Properties 'msWMI-Name', 'msWMI-Parm1', 'msWMI-Parm2', 'msWMI-ID' @serverParams -ErrorAction Stop)
    if ($results.Count -gt 0) {
        return $results[0]
    }
    return $null
}

# msWMI-Parm2 is a hand-rolled, length-prefixed encoding (not a delimiter-only format,
# since a query can itself contain semicolons): "<count>;3;10;<len>;WQL;<namespace>;<query>;"
# repeated once per query. 3 and 10 are fixed flags GPMC itself always writes.
function ConvertTo-WmiFilterParm2($Queries) {
    $parm2 = "$(@($Queries).Count);"
    foreach ($q in @($Queries)) {
        $namespace = [string]$q.namespace
        $query = [string]$q.query
        $parm2 += "3;10;$($query.Length);WQL;$namespace;$query;"
    }

    return $parm2
}

function ConvertFrom-WmiFilterParm2([string]$Parm2) {
    $queries = @()
    if ([string]::IsNullOrEmpty($Parm2)) {
        return $queries
    }

    $firstSemicolon = $Parm2.IndexOf(';')
    $count = [int]$Parm2.Substring(0, $firstSemicolon)
    $rest = $Parm2.Substring($firstSemicolon + 1)

    for ($i = 0; $i -lt $count; $i++) {
        # $rest looks like "3;10;<len>;WQL;<namespace>;<query>;..." - split into at most
        # 6 fields so the query text (fields[5], up to $len characters) is never itself
        # split on an embedded semicolon.
        $fields = $rest.Split(';', 6)
        $len = [int]$fields[2]
        $namespace = $fields[4]

        $afterNamespace = $fields[5]
        $query = $afterNamespace.Substring(0, $len)
        $remainder = $afterNamespace.Substring($len)
        if ($remainder.StartsWith(';')) {
            $remainder = $remainder.Substring(1)
        }
        $rest = $remainder

        $queries += [pscustomobject]@{
            namespace = $namespace
            query     = $query
        }
    }

    return $queries
}

function Get-WmiFilterResult($AdObject) {
    if ($null -eq $AdObject) {
        return [pscustomobject]@{
            exists             = $false
            guid               = $null
            name               = $null
            description        = $null
            queries            = @()
            distinguished_name = $null
        }
    }

    return [pscustomobject]@{
        exists             = $true
        guid               = ([string]$AdObject.'msWMI-ID' -replace '[{}]', '')
        name               = [string]$AdObject.'msWMI-Name'
        description        = ([string]$AdObject.'msWMI-Parm1').TrimEnd()
        queries            = @(ConvertFrom-WmiFilterParm2 ([string]$AdObject.'msWMI-Parm2'))
        distinguished_name = [string]$AdObject.DistinguishedName
    }
}
