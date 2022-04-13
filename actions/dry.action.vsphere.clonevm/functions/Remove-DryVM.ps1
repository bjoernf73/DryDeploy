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

function Remove-DryVM {
    param (
        [Parameter(Mandatory=$true)]
        [psobject]$VMSpec
    )

    try {
        $ExistingVM = Get-VM -Name $VMSpec.NewVMSplat.Name -ErrorAction Stop
    }
    catch {
        if ($_.ToString() -match "VM with name '$($VMSpec.NewVMSplat.Name)' was not found") {
            ol i 'VM does not exist',"$($VMSpec.NewVMSplat.Name)"
        }
        else {
            ol w "Some error occurred querying for VM '$($VMSpec.NewVMSplat.Name)'"
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    if ($ExistingVM) {
        try {
            if ($ExistingVM.PowerState -ne 'PoweredOff') {
                ol i "Shutting down VM","$($VMSpec.NewVMSplat.Name)"
                Stop-VM -VM "$($VMSpec.NewVMSplat.Name)" -Confirm:$False
            }

            $VMPoweredOff = $False
            do {
                Start-Sleep -Seconds 5
                if ((Get-VM -Name $VMSpec.NewVMSplat.Name -ErrorAction Stop).PowerState -eq 'PoweredOff') {
                    $VMPoweredOff = $True
                    ol i "Power state on VM","PoweredOff"
                }
                else {
                    ol i "Power state on VM","PoweredOn (waiting for shutdown)"
                }
            }
            while (-not $VMPoweredOff)
            
            ol w 'Permamently deleting VM',"$($VMSpec.NewVMSplat.Name)"
            Remove-VM -VM "$($VMSpec.NewVMSplat.Name)" -DeletePermanently -Confirm:$False 
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}