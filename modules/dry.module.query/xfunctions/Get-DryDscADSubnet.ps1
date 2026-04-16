# This module is an action module for use with DryDeploy. It runs a DSC
# Config on a target
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.dsc.run/main/LICENSE
#


function Get-DryDscADSubnet{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [psobject]$Resource,

        [Parameter(Mandatory=$true)]
        [psobject]$Configuration
    )
    try{
        # Holds all subnets at the site, but the resource's own subnet is first, then the rest
        $AllSubnetsatSite = @()

        # Get resource's site
        $Site = $Configuration.CoreConfig.network.sites | Where-Object{ $_.Name -eq $Resource.network.site }
        if(($Site -is [array]) -or ($null -eq $Site)){
            Write-Error "Multiple or no sites matched pattern '$($Resource.network.site)'" -ErrorAction Stop
        }

        # Get the resource's subnet. That must exist, and there should be only one
        $Subnet = $Site.Subnets | Where-Object{ $_.Name -eq $Resource.network.subnet_name }
        if(($Subnet -is [array]) -or ($null -eq $Subnet)){
            Write-Error "Multiple or no subnets matched pattern '$($Resource.network.subnet_name)'" -ErrorAction Stop
        }

        # Get the other subnet's at that site. Might be one, might be many, might be none
        $OtherSubnets = @( $Site.Subnets | Where-Object{ $_.Name -ne $Resource.network.subnet_name })

        # First add resource's subnet
        $Subnetobject = Invoke-PSipcalc -networkaddress "$($Subnet.ip_subnet)/$($Subnet.subnet_mask)"
        $AllSubnetsatSite+= "$($Subnetobject.NetworkAddress)/$($Subnetobject.NetworkLength)"

        # then the others
        foreach($OtherSubnet in $OtherSubnets){
            $Subnetobject = Invoke-PSipcalc -networkaddress "$($OtherSubnet.ip_subnet)/$($OtherSubnet.subnet_mask)"
            $AllSubnetsatSite+= "$($Subnetobject.NetworkAddress)/$($Subnetobject.NetworkLength)"
        }

        $AllSubnetsatSite
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}