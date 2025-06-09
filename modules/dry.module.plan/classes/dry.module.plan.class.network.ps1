using Namespace System.Collections.Generic
using Namespace System.Collections
class Network{
    [string]$Name
    [string]$Switch_Name
    [string]$Ip_Subnet 
    [string]$Subnet_Mask
    [string]$Default_Gateway
    [string]$Reverse_Zone
    [array]$Dns
    [array]$Dns_Forwarders
    [PSCustomObject]$Dhcp
    [string]$Ip_Address

    Network (
         [PSCustomObject]$NetworkRef,
         [array]$Sites
    ){
        $Site = $Sites | 
        Where-Object{ 
            $_.Name -eq $NetworkRef.site 
        }
        
        if($null -eq $Site){
            Write-Error "No sites matched pattern '$($NetworkRef.site)'" -ErrorAction Stop
        }
        elseif($Site -is [array]){
            Write-Error "Multiple sites matched pattern '$($NetworkRef.site)'" -ErrorAction Stop
        }
    
        $Subnet = $Site.Subnets | 
        Where-Object{ 
            $_.Name -eq $NetworkRef.subnet_name 
        }
        
        if($null -eq $Subnet){
            Write-Error "No subnets matched pattern '$($NetworkRef.subnet_name)'" -ErrorAction Stop
        }
        elseif($Subnet -is [array]){
            Write-Error "Multiple subnets matched pattern '$($NetworkRef.subnet_name)'" -ErrorAction Stop
        }

        $This.Name            = $Subnet.Name
        $This.Switch_Name     = $Subnet.Switch_Name
        $This.Ip_Subnet       = $Subnet.Ip_Subnet
        $This.Subnet_Mask     = $Subnet.Subnet_Mask
        $This.Default_Gateway = $Subnet.Default_Gateway
        $This.Reverse_Zone    = $Subnet.Reverse_Zone
        $This.Dns             = $Subnet.Dns
        $This.Dhcp            = $Subnet.Dhcp

        if($NetworkRef.ip_index){
            $Snet = $Subnet.ip_subnet + '/' + $Subnet.subnet_mask
            $This.ip_address = ((Invoke-PSipcalc -NetworkAddress $Snet -Enumerate).IPenumerated)[($($NetworkRef.ip_index)-1)]
        } 
        elseif($NetworkRef.ip_address){
            $This.ip_address = $NetworkRef.ip_address
        }
        else{
            ol w "The Resource $($This.Name) does not have an IP address"
        }

        if($Subnet.dns_forwarders){
            $This.Dns_Forwarders = $Subnet.dns_forwarders
        }
    }
}