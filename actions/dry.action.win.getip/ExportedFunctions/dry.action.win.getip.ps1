using namespace System.Collections
# This module is an action module for use with DryDeploy. It finds the IP 
# of a DHCP resource and updates the resource, so subsequent actions
# may target the resource
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
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

Function dry.action.win.getip {
    [CmdletBinding()]  
    Param (
        [Parameter(Mandatory,HelpMessage="The resolved action object")]
        [PSObject]
        $Action,

        [Parameter(Mandatory)]
        [PSObject]
        $Resolved,

        [Parameter(Mandatory,HelpMessage="The resolved global configuration
        object")]
        [PSObject]
        $Configuration,

        [Parameter(HelpMessage="Hash directly from the command line to be 
        added as parameters to the function that iniates the action")]
        [HashTable]
        $ActionParams
    )
    try {
        [ArrayList] $DnsServers = $Action.Resource.Resolved_Network.Dns
        [String]    $ResourceFQDNName = $Action.Resource.Name + '.' + $Action.Resource.Resolved_Network.DomainFQDN
        [Boolean]   $IPResolved = $False 
        foreach ($DnsServer in $DnsServers) {
            $ResourceIPobj = Resolve-DnsName -Name $ResourceFQDNName -Server $DnsServer -Type A -ErrorAction SilentlyContinue
            if ($null -ne $ResourceIPobj.IPAddress) {
                $IPResolved = $true
                Break
            }
        }

        if ($IPResolved) {
            $Action.Resource.Network.UpdateDHCPIP($ResourceIPobj.IPAddress)
            ol i @("Found and updated '$ResourceFQDNName' with IP","$($ResourceIPobj.IPAddress)")
        }
        else {
            Throw "Unable to find resource '$ResourceFQDNName' at DNSServers '$DnsServers'"
        } 
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        @(Get-Variable -Scope Script).ForEach({
            Remove-Variable -Name $_ -ErrorAction Ignore
        })

        ol i "Action 'win.getip' is finished" -sh
    }
}