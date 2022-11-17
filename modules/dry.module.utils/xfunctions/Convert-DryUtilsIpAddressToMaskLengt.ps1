function Convert-DryUtilsIpAddressToMaskLength {
    [CmdletBinding()]
    param (
        [string]$IPAddress
    )

    $Result = 0; 
    [IPAddress]$IP = $IPAddress
    $Octets = $IP.IPAddressToString.Split('.');
    foreach($Octet in $Octets) {
        while(0 -ne $Octet) {
            $Octet = ($Octet -shl 1) -band [byte]::MaxValue
            $Result++
        }
    }
    return $Result
}