# This module is an action module for use with DryDeploy. It uses the 
# VMware vSphere API to clone a template, and customize the new vm. 
#
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.vsphere.clonevm/main/LICENSE
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

function Connect-DryVIServer {
    [CmdletBinding()]
    param (
        [ValidateScript({Test-Connection $_ })]
        [Parameter(Mandatory)]
        [String]$vcenter,

        [Parameter(Mandatory)]
        [PSCredential]$Credential
    )

    try {
        ol i @("Target vCenter",$Vcenter)
        $ConnectVIServerParams = @{
            Server        = $Vcenter
            Credential    = $Credential
            WarningAction = 'Continue'
            Force         = $true
        }
        [Array]$Connection = [VMware.VimAutomation.ViCore.Util10.VersionedObjectImpl]$Connection = Connect-VIServer @ConnectVIServerParams

        ol i @("Connected to vCenter","$($Connection.Name):$($Connection.Port) with user $($Connection.User)")
        Return $Connection
    }
    catch {
        ol w "Unable to connect to vCenter","$($Connection.Name):$($Connection.Port) with user $($Connection.User)"
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
        Remove-Variable -Name ConnectVIServerParams -ErrorAction Ignore
    }      
}