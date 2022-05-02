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

function Add-DryVM {
    [CmdletBinding()]  
    param (
        [String]$Vcenter,

        [PSCredential]$Credential,

        [PSObject]$VMSpec,

        $WaitTools = $True,

        $Force = $GLOBAL:dry_var_global_Force
    )
    try {
        # Connect to vcenter
        $VcenterConnection = Connect-DryVIServer -Vcenter $Vcenter -Credential $Credential

        if ($Force) {
            Remove-DryVM -VMSpec $VMSpec
        }

        if ($VMSpec.VMCluster) {
            ol i "VMCluster","$($VMSpec.VMCluster)"
            $VMCluster = Get-Cluster -Name $VMSpec.VMCluster
        }
        elseif ($VMSpec.VMHost) {
            ol i "VMhost","$($VMSpec.VMHost)"
            $VMHost = Get-VMHost -Name $VMSpec.VMHost -ErrorAction Stop 
            $Datastore = @(Get-Datastore -RelatedObject $VMhost -Name $VMSpec.Systemdisk.DataStoreRegEx | Sort-Object -Property FreeSpaceGB -Descending)[0]
 
        } 
        else {
            ol i "VMCluster selection","Unspecified"
            
            # Try to get a DRSEnabled Cluster 
            $VMCluster = Get-Cluster | 
            Where-Object {
                $_.DRSEnabled -eq $True
            }

            if ($VMCluster) {
                ol i "DRSEnabled VMCluster found","$($VMCluster.Name)"
                $Datastores = @(Get-Datastore -RelatedObject $VMCluster | Sort-Object -Property FreeSpaceGB -Descending)

                if ($DataStores.Count -gt 0) {
                    $Datastore = $DataStores[0]
                }
                [array]$VMHosts = Get-VMHost | Where-Object {
                    $_.ParentId -eq $VMCluster.Id
                }
                
                $VMHost = Get-Random $VMHosts
                ol i "VMHost","$VMHost"
            }
            else {
                [array]$VMHosts = Get-VMHost  

                $VMHost = Get-Random $VMHosts
                ol i "VMHost","$VMHost"
                $Datastore = @(Get-Datastore -RelatedObject $VMhost -Name $VMSpec.Systemdisk.DataStoreRegEx | Sort-Object -Property FreeSpaceGB -Descending)[0]
            }
        }
        
        # make sure the location (folder) to store vms exists. If not, create it. 
        if (-not (Get-Folder -Name $VMSpec.NewVMSplat.location -location VM -ErrorAction SilentlyContinue )) {
            New-Folder -Name $VMSpec.NewVMSplat.location -location VM -ErrorAction Stop
        }
       
        [hashtable]$NewVMParams = @{}
        $($VMSpec.NewVMSplat) |
        Get-Member -MemberType Properties | ForEach-Object { 
            $NewVMParams.Add($_.Name,$($VMSpec.NewVMSplat).($_.Name)) 
        }
        
        if ($null -ne $VMCluster) { 
            $NewVMParams.Add("ResourcePool", $VMCluster)
            $NewVMParams.Add("VMHost", $VMHost) 
        }
        elseif ($null -ne $VMHost) { 
            $NewVMParams.Add("VMHost", $VMHost) 
        }

        ol v "New-VM Params:"
        ol v -hash $NewVMParams 
        ol i "Creating/Cloning VM" -sh
        [VMware.VimAutomation.ViCore.Impl.V1.Inventory.InventoryItemImpl]$VM = New-VM @NewVMParams -Datastore $DataStore -ErrorAction Stop

        # Setting additional settings
        [hashtable]$SetVMParams = @{}
        $($VMSpec.SetVMSplat) | 
        Get-Member -MemberType Properties | 
        ForEach-Object { 
            if ($_.Name -ne 'HardwareVersion') {
                $SetVMParams.Add($_.Name,$($VMSpec.SetVMSplat).($_.Name)) 
            }
        }
        ol v 'Set-VM Params:'
        ol v -hash $SetVMParams
        ol v "Trying to run 'Set-VM' on","$($VM.name)"
        
        ol i "Setting VM additional properties (Set-VM)" -sh
        Set-VM -VM $VM @SetVMParams -Confirm:$False 
        
        # Set-VM fails if you try to set the hardware version that
        # the vm already has. Test if different before set
        if ($VMSpec.SetVMSplat.HardwareVersion) {
            if ($VMSpec.SetVMSplat.HardwareVersion -ne $vm.HardwareVersion) {
                ol i 'Changing HardwareVersion',"$($vm.HardwareVersion) ==> $($VMSpec.SetVMSplat.HardwareVersion)"
                Set-VM -VM $VM -HardwareVersion $VMSpec.SetVMSplat.HardwareVersion -Confirm:$false 
            }  
        }

        # System disk is currently the only disk attached to the vm
        $SystemDisk = Get-Harddisk -VM $VM -ErrorAction Stop 
        $VMSpecSystemDisk = $VMSpec.SystemDisk
        
        # if property diskGB is used, convert to CapacityGB which is the property used by 
        # Set-Harddisk
        if ($VMSpecSystemDisk.DiskGB) {
            $VMSpecSystemDisk | Add-Member -MemberType NoteProperty -Name 'CapacityGB' -Value $VMSpecSystemDisk.DiskGB
        }
        if ($VMSpecSystemDisk.CapacityGB) {
            if ($VMSpecSystemDisk.CapacityGB -ne $SystemDisk.CapacityGB) {
                ol i "Changing System Disk size","$($SystemDisk.CapacityGB) ==> $($VMSpecSystemDisk.CapacityGB)"
                Set-Harddisk -HardDisk $SystemDisk -CapacityGB $VMSpecSystemDisk.CapacityGB -Confirm:$false
            }
        }

        if ($VMSpecSystemDisk.DiskStorageFormat) {
            $VMSpecSystemDisk | 
            Add-Member -MemberType NoteProperty -Name 'StorageFormat' -Value $VMSpecSystemDisk.DiskStorageFormat
        }

        if ($VMSpecSystemDisk.StorageFormat) {
            if ($VMSpecSystemDisk.StorageFormat -ne $SystemDisk.StorageFormat) {
                ol i "Changing System Disk storage format","$($SystemDisk.StorageFormat) ==> $($VMSpecSystemDisk.StorageFormat)"
                Set-Harddisk -HardDisk $SystemDisk -StorageFormat $VMSpecSystemDisk.StorageFormat -Confirm:$false 
            }
        }

        # Adding additional disks
        if ($VMSpec.AdditionalDisks) {
            ol i "Additional Disks" -sh
            ForEach ($AdditionalDisk in $VMSpec.AdditionalDisks) {
                Remove-Variable -Name DataStore -ErrorAction Ignore
                if ($VMHost) {
                    $DataStore = Get-DataStore -VMHost $VMHost -Name $AdditionalDisk.DataStoreRegEx -ErrorAction Stop 
                }
        
                $NewDiskPossibleParams = @('CapacityGB','Persistence','StorageFormat','DiskType')
                [hashtable]$Params = @{}
                $AdditionalDisk.PSObject.Properties | ForEach-Object {
                    if ($NewDiskPossibleParams -contains $_.Name) {
                        $Params += @{ $_.Name = $_.Value }
                    } 
                }
 
                # loop through $Params and log keys and values to debug stream. The globally scoped 
                # DebugPreference variable should be set to Continue so function continues
                ol v "New-Harddisk Params:"
                ol v -hash $Params
               
                
                ol i "Creating new additional hard disk"
                New-harddisk -VM $VM -Datastore $DataStore @Params -Confirm:$False 
            }
        }

        # Configure Virtualization Based Security
        if ($VMSpec.VBS) {
            ol i "Configuring VBS (Virtualization Based Security)" -sh
            if (-not ($VM.ExtensionData.Config.Flags.VbsEnabled)) {
                ol i "VBS state",'OFF - reconfiguring...'
                $VMConfigSpec                      = New-Object VMware.Vim.VirtualMachineConfigSpec
                $VMConfigSpec.Firmware             = [VMware.Vim.GuestOsDescriptorFirmwareType]::efi
                $VMConfigSpec.NestedHVEnabled      = $True
                $VMConfigBoot                      = New-Object VMware.Vim.VirtualMachineBootOptions
                $VMConfigBoot.EfiSecureBootEnabled = $true
                $VMConfigSpec.BootOptions          = $VMConfigBoot
                $VMConfigFlags                     = New-Object VMware.Vim.VirtualMachineFlagInfo
                $VMConfigFlags.VbsEnabled          = $true
                $VMConfigFlags.VvtdEnabled         = $true
                $VMConfigSpec.flags                = $VMConfigFlags
                
                $VM.ExtensionData.ReconfigVM($VMConfigSpec)
                ol i "VBS state","ON"
            }
            else {
                ol i "VBS state","ON"
            }
        }
        else {
            ol i "VBS should be turned off according to configuration" -sh
        }

        # Add OSCustomizaion. This adds name, regionalsettings and such
        $SpecName = Get-RandomHex -Length 8 
        
        # $VMSpec.OSCustomization
        [hashtable]$OSCustParams = @{}
        $($VMSpec.OSCustomization).PSObject.Properties | 
        ForEach-Object { 
            $OSCustParams += @{ $_.Name = $_.Value }
        }
        ol v "OS Customization Params:"
        ol v -hash $OSCustParams 
        
        ol i "OS Customization" -sh
        New-OSCustomizationSpec @OSCustParams -Name $SpecName -Confirm:$False 

        Start-Sleep -Seconds 2
        # Adding NetworkCustomization. First get mac of the nic
        $MacAddr = (Get-NetworkAdapter -VM $VM -ErrorAction Stop).MacAddress
        
        # $VMSpec.NetworkCustomization
        [hashtable]$NetworkCustParams = @{}
        $($VMSpec.NetworkCustomization).PSObject.Properties | 
        ForEach-Object {
            if ($_.Name -ne 'dns') {
                # all values are strings, except dns, which is an array
                $NetworkCustParams += @{ $_.Name = $_.Value }
            } 
            else {
                $NetworkCustParams += @{ 'dns' = @($_.Value) }
            } 
        }
        ol v "Network Customization Params"
        ol v -hash $NetworkCustParams
        Start-Sleep -Seconds 2
        
        # set the OSCustomizationNicMapping
        ol i "Getting OS Customization NIC-mapping" -sh
        Get-OSCustomizationNicMapping -OSCustomizationSpec $specname |
        Set-OSCustomizationNicMapping -NetworkAdapterMac $MacAddr @NetworkCustParams -Confirm:$False 

        Start-Sleep -Seconds 1
        # Apply the OSCustomization
        ol i "Applying OS Customization" -sh 
        Set-VM -VM $VM -OSCustomizationSpec $SpecName -Confirm:$false -ErrorAction Stop 
        
        Start-Sleep -Seconds 2
        # Make sure netadapter is connected
        Get-NetworkAdapter -VM $VM |
        ForEach-Object { 
            ol i "Configuring NIC" -sh
            Set-NetworkAdapter $_ -StartConnected $True -ErrorAction Stop -Confirm:$False 
        }

        Start-Sleep -Seconds 2
        
        # Start the VM
        ol i "Starting the VM" -sh
        Start-VM -VM $VM.Name -Confirm:$False -ErrorAction Stop 
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        if ($VcenterConnection) {
            Start-Sleep -seconds 5
            Disconnect-DryVIServer -VIConnection $VcenterConnection
        }
    }
}