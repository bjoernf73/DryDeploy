# This module is an action module for use with DryDeploy. It runs a DSC 
# Config on a target
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.dsc.run/main/LICENSE
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

Function Get-DryDscADSubnet {
    [CmdletBinding()]  
    Param (
        [Parameter(Mandatory=$true)]
        [psobject]$Resource,

        [Parameter(Mandatory=$true)]
        [psobject]$Configuration
    )
    Try {
        # Holds all subnets at the site, but the resource's own subnet is first, then the rest
        $AllSubnetsatSite = @()
        
        # Get resource's site
        $Site = $Configuration.network.sites | Where-Object { $_.Name -eq $Resource.network.site }
        If (($Site -is [array]) -or ($Null -eq $Site)) {
            Write-Error "Multiple or no sites matched pattern '$($Resource.network.site)'" -ErrorAction Stop
        }

        # Get the resource's subnet. That must exist, and there should be only one
        $Subnet = $Site.Subnets | Where-Object { $_.Name -eq $Resource.network.subnet_name }
        If (($Subnet -is [array]) -or ($Null -eq $Subnet)) {
            Write-Error "Multiple or no subnets matched pattern '$($Resource.network.subnet_name)'" -ErrorAction Stop
        }

        # Get the other subnet's at that site. Might be one, might be many, might be none
        $OtherSubnets = @( $Site.Subnets | Where-Object { $_.Name -ne $Resource.network.subnet_name })
        
        # First add resource's subnet
        $Subnetobject = Invoke-PSipcalc -networkaddress "$($Subnet.ip_subnet)/$($Subnet.subnet_mask)"
        $AllSubnetsatSite+= "$($Subnetobject.NetworkAddress)/$($Subnetobject.NetworkLength)"

        # then the others
        ForEach ($OtherSubnet in $OtherSubnets) {
            $Subnetobject = Invoke-PSipcalc -networkaddress "$($OtherSubnet.ip_subnet)/$($OtherSubnet.subnet_mask)"
            $AllSubnetsatSite+= "$($Subnetobject.NetworkAddress)/$($Subnetobject.NetworkLength)"
        }

        $AllSubnetsatSite
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}