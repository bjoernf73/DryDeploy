# This module is an action module for use with DryDeploy. It runs a DSC 
# Config on a target
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.dsc.run/main/LICENSE
# 


function Get-DryDscReverseZones{
    [CmdletBinding()]  
    param(
        [Parameter(Mandatory=$true)]
        [psobject]$Resource,

        [Parameter(Mandatory=$true)]
        [psobject]$Configuration
    )
    try{
        # Holds all reverse zones at site
        $AllReverseZonesAtSite = @()
        
        # Get resource's site
        $Site = $Configuration.CoreConfig.network.sites | 
        Where-Object{ $_.Name -eq $Resource.network.site }
        if(($Site -is [array]) -or ($null -eq $Site)){
            Write-Error "Multiple or no sites matched pattern '$($Resource.network.site)'" -ErrorAction Stop
        }

        # Get the resource's subnet. That must exist, and there should be only one
        $Subnets = @($Site.Subnets)
        if($null -eq $Subnets){
            Write-Error "No subnets matched pattern '$($Resource.network.subnet_name)'" -ErrorAction Stop
        }

        # then the others
        foreach($Subnet in $Subnets){
            $AllReverseZonesAtSite+= $Subnet.reverse_zone
        }

        $AllReverseZonesAtSite
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}