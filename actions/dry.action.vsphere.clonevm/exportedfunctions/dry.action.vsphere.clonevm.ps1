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

function dry.action.vsphere.clonevm {

    [CmdletBinding()]  
    param (
        [Parameter(Mandatory,HelpMessage="The resolved action object")]
        [PSObject]$Action,

        [Parameter(Mandatory,HelpMessage="The resolved resource object")]
        [PSObject]$Resource,

        [Parameter(Mandatory,HelpMessage="The resolved environment configuration object")]
        [PSObject]$Configuration,

        [Parameter(Mandatory,HelpMessage="ResourceVariables contains resolved variable values from the configurations common_variables and resource_variables combined")]
        [System.Collections.Generic.List[PSObject]]$ResourceVariables,

        [Parameter(Mandatory=$False,HelpMessage="Hash directly from the command line to be added as parameters to the function that iniates the action")]
        [HashTable]$ActionParams
    )
    
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # 
    #   vsphere.clonevm
    #
    #   We need an object defining the virtual machine that consists of 6 parts:
    #   1. $NewVMSplat which is splatted to New-VM 
    #   2. $VMLayout which is splatted to Set-VM (options that New-VM doesn't support)
    #   3. $SystemDisk, it's size, format and placement. The systemdisk is contained in 
    #      the VMTemplate, but may have to be reconfigured. 
    #   4. $OSCustomization, properties that goes in the unattend handled by vSphere
    #   5. $NetworkCustomization that configures the network properties
    #   6. $AdditionalDisks, an array defining all additional disks for the VM
    #
    #   Example configuration: 
    #   
    #    { 
    #        "vm_template": "ws2019-standard-gui-ltsc",
    #        "vm_layout": {
    #            "numcpu": "4",
    #            "corespersocket": "1",
    #            "memorygb": "4",
    #            "hardwareversion": "vmx-15"
    #        },
    #        "vm_disk_layout": {
    #            "system_disk": 
    #            {
    #                "capacitygb": "100",
    #                "storageformat": "Thin",
    #                "datastore": "fast"
    #            }
    #        },
    #        "os_customization": {
    #            "FullName": "Administrator",
    #            "AdminPassword": "___pwd___ws2019-local-admin___",
    #            "AutoLogonCount": 1,
    #            "ChangeSid": true,
    #            "LicenseMaxConnections": 5,
    #            "LicenseMode": "PerSeat", 
    #            "NamingScheme": "Fixed", 
    #            "OSType": "Windows",  
    #            "TimeZone": "Central Europe",
    #            "Domain": "###DomainFQDN###",
    #            "NamingPrefix": "###ComputerName###", 
    #            "Description": "###ComputerDescription###",
    #            "OrgName":  "###OrgName###",
    #            "DomainCredentials": "___cred___domain-admin___",
    #            "GuiRunOnce": ["powershell.exe -ExecutionPolicy bypass -File C:\\GITs\\DryTools\\ConfigureWinRM-https.ps1"]
    #        }
    #    }
    #
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    
    try {    
        if ($GLOBAL:Force -eq $True) {
            ol w 'Forced deployment - existing resources will be destroyed!'
        }
        else {
            ol i 'Friendly deployment - existing resoures will be kept'
        }
        ol i @('Role',"$($Resource.Role)")
        
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   OPTIONS
        #
        #   Resolve sources, temporary target folders, and other options 
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $OptionsObject     = Resolve-DryActionOptions -Resource $Resource -Action $Action
        $ConfigSourcePath  = $OptionsObject.ConfigSourcePath
        $HardwareType      = $OptionsObject.ActionType

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #   Hardware Type
        #
        #   The $OptionsObject ActionType property for the CloneVM Actions resolves 
        #   the instance's hardware type.
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        ol i @('Hardware Type',"$HardwareType")

        # Get the configuration. The configuration may be in one or multiple json or jsonc files
        Remove-Variable -Name RoleConfiguration,ConfigurationPathFiles,VMConfFile,VMConfObject -ErrorAction Ignore
        $RoleConfiguration = New-Object -TypeName PSObject
        $ConfigurationPathFiles = @(Get-ChildItem -Path (Join-Path -Path $ConfigSourcePath -ChildPath '*') -Include "*.jsonc","*.json" -ErrorAction Stop)
        
        foreach ($VMConfFile in $ConfigurationPathFiles) {
            # Pick up each files configuration, and merge into $RoleConfiguration
            $VMConfObject = Get-DryCommentedJson -Path $VMConfFile.FullName -ErrorAction Stop
            $RoleConfiguration = (Merge-DryPSObjects -FirstObject $RoleConfiguration -SecondObject $VMConfObject)
        }

        $RoleConfiguration = Resolve-DryReplacementPatterns -InputObject $RoleConfiguration -Variables $ResourceVariables

        Remove-Variable -Name PlatformConfiguration -ErrorAction Ignore
        ol i 'Getting Platform Configuration','vsphere'
        $PlatformConfiguration = $Configuration.platforms | 
        Where-Object { 
            $_.Type -eq 'vsphere' 
        }
        if ($null -eq $PlatformConfiguration) {
            throw "Unable to find `$Configuration.platforms where 'type' -eq 'vsphere'" 
        }

        [String]$VMTemplate = $RoleConfiguration.vm_template
        if ($Null -eq $VMTemplate) {
            throw "Unable to find .vm_template in configuration" 
        }
        else {
            ol i 'Found vm_template name in configuration',"$VMTemplate"
        }

        [PSObject]$VMLayout = $RoleConfiguration.vm_layout
        if ($Null -eq $VMLayout) {
            throw "Unable to find .vm_layout in configuration" 
        }
        else {
            ol i 'Found vm_layout in configuration'
        }

     
        [PSObject]$VMDiskLayout = $RoleConfiguration.vm_disk_layout
        if ($Null -eq $VMDiskLayout) {
            throw "Unable to find .vm_disk_layout in configuration"
        }
        else {
            ol i 'Found vm_disk_layout in configuration'
        }
   
        [PSObject]$OSCustomization = $RoleConfiguration.os_customization
        if ($Null -eq $OSCustomization) {
            throw "Unable to find .os_customization in configuration"
        }
        else {
            ol i 'Found os_customization in configuration'
        }

        # Put in clear text passwords - they references credentials a string like '___pwd___ws2019-local-admin___', 
        # where 'ws2019-local-admin' is a name for a credential 
        ol i 'Replacing Clear-Text passwords in OSCustomization'
        $OSCustomization = Resolve-DryPassword -InputObject $OSCustomization

        # Put in credentials objects - they references credentials a string like '___cred___domain-admin___', 
        # where 'domain-admin' is a name for a credential 
        ol i 'Replacing Credentials in OSCustomization'
        $OSCustomization = Resolve-DryCredential -InputObject $OSCustomization

        ol i 'Resource OS Type',$OSCustomization.OSType
        if ($OSCustomization.OSType -eq 'linux') {
            $OSCustomization | 
            Add-Member -MemberType NoteProperty -Name DnsServer -Value $Resource.Resolved_Network.dns
        }

        # Properties to splat to New-VM
        $NewVMSplat = New-Object -TypeName PSCustomObject -Property @{
            template = $RoleConfiguration.vm_template
            name = $Resource.name
        }
        
        # The location of the VM (in the vSphere console) may be specified in the role configuration,
        # or, if it isn't, it must be specified in the platformconfiguration
        if ($RoleConfiguration.vm_location) {
            $NewVMSplat | 
            Add-Member -MemberType NoteProperty -Name 'location' -Value $RoleConfiguration.vm_location
        }
        else {
            $NewVMSplat | 
            Add-Member -MemberType NoteProperty -Name 'location' -Value $PlatformConfiguration.vm_location
        }

        # Add virtual network to connect VM to. $Resource.Resolved_Network.switch_name
        $NewVMSplat | 
        Add-Member -MemberType NoteProperty -Name 'networkname' -Value $Resource.Resolved_Network.switch_name
        

        [PSObject]$SystemDisk = $VMDiskLayout.system_disk
        
        
        $DatastoreObject = $PlatformConfiguration.datastores | 
        Where-Object { $_.Name -eq $VMDiskLayout.system_disk.datastore }

        [string]$DatastoreRegex = $DatastoreObject.datastoreregex
        if ($Null -eq $DatastoreRegex) {
            throw "Unable to find datastoreregex for '$($SystemDisk.datastore)'"
        }
        ol v "Found datastore '$($SystemDisk.datastore)'"
        
        $SystemDisk | 
        Add-Member -MemberType NoteProperty -Name datastoreregex -Value $DatastoreRegex
            
        # The datastore, which represents an alias, can then be removed from the object
        $SystemDisk.PSObject.Properties.Remove('datastore')
        
        # Network
        if (($Resource.Resolved_Network.ip_address) -and (-not ($Resource.Resolved_Network.ip_address -eq 'dhcp'))) {
            $NetworkCustomization = New-Object -TypeName PSCustomObject -Property @{
                ipmode = "UseStaticIP"
                subnetmask = $Resource.Resolved_Network.subnet_mask
                defaultgateway = $Resource.Resolved_Network.default_gateway
                ipaddress = $Resource.Resolved_Network.ip_address
            }

            # The DNS property of the vmware network customization is a windows-only property. 
            if ($OSCustomization.OSType -eq "Windows") {
                if ($Resource.Resolved_Network.ip_address -eq $Configuration.network.domain.pdc_emulator) {
                    $NetworkCustomization | Add-Member -MemberType NoteProperty -Name 'dns' -Value ($Resource.Resolved_Network.dns + $Resource.Resolved_Network.dns_forwarders)
                }
                else {
                    $NetworkCustomization | Add-Member -MemberType NoteProperty -Name 'dns' -Value $Resource.Resolved_Network.dns
                }
            }
        }
        else {
            $NetworkCustomization = New-Object -TypeName PSCustomObject -Property @{
                ipmode = "UseDHCP"
            }
        }
        
        # Additional disks, if any
        if ($VMDiskLayout.additional_disks) {
            
            [Array]$AdditionalDisks = $VMDiskLayout.additional_disks
            foreach ($AdditionalDisk in $AdditionalDisks) {

                $DatastoreObject = $PlatformConfiguration.datastores | 
                Where-Object { $_.Name -eq $AdditionalDisk.datastore }

                [string]$DatastoreRegex = $DatastoreObject.datastoreregex
                
                ol v "Found additional disk datastore '$DatastoreRegex'"
                $AdditionalDisk | Add-Member -MemberType NoteProperty -Name datastoreregex -Value $DatastoreRegex
                
                # The datastore, which represents an alias, can then be removed from the object
                $AdditionalDisk.PSObject.Properties.Remove('datastore') 
            }
        }

        # Create an object of the properties above
        $VirtualMachine = New-Object -TypeName PSCustomObject -Property @{
            NewVMSplat           = $NewVMSplat
            SetVMSplat           = $VMLayout
            SystemDisk           = $SystemDisk
            OSCustomization      = $OSCustomization
            NetworkCustomization = $NetworkCustomization
            AdditionalDisks      = $AdditionalDisks
            VBS                  = $false
        }
        switch ($OSCustomization.OSType) {
            'windows' {
                $VirtualMachine.VBS = $True 
            }
            default {
                # keep the default
            }
        }

        if ($PlatformConfiguration.VMHost) {
            $VirtualMachine | Add-Member -MemberType NoteProperty -Name 'VMHost' -Value $PlatformConfiguration.VMHost
        }

        if ($PlatformConfiguration.VMCluster) {
            $VirtualMachine | Add-Member -MemberType NoteProperty -Name 'VMCluster' -Value $PlatformConfiguration.VMCluster
        }

        # explicitly load VMware.VimAutomation.Core so the verbose output can be redirected
        Import-Module -Name VMware.VimAutomation.Core -Force -Verbose:$False -ErrorAction Stop | Out-Null 

        #! Move this down
        $CredAlias = $Action.credentials.credential1
        $ConnectionURL = $PlatformConfiguration.connection.url

        ol i 'Credential alias',"$CredAlias"
        ol i 'Connection URL',"$ConnectionURL"
        
        $Credential = Get-DryCredential -Alias $CredAlias -EnvConfig $GLOBAL:EnvConfigName
        Add-DryVM -vcenter $ConnectionURL -vmspec $VirtualMachine -Credential $Credential
        
        
        if ($NetworkCustomization.ipaddress) {
            $TargetVMIPAddress = $NetworkCustomization.ipaddress
            ol i 'VM static IP address',"$TargetVMIPAddress"
        }
        else {
            ol i 'VM dynamic IP address',"(searching....)"
            $TargetVMIPAddress = Get-DryVMIPAddress -VMName $NewVMSplat.Name -Credential $Credential -vCenter $ConnectionURL
            # Used by DryDeploy.ps1
            $GLOBAL:ResourceIP = $TargetVMIPAddress
            ol i 'VM dynamic IP address',"$TargetVMIPAddress"
        }

        # Wait for the virtual machine to become available after os customization
        switch ($OSCustomization.OSType) {
            'linux' {
                $WaitParameters = @{
                    IP                       = $TargetVMIPAddress
                    Computername             = $Resource.name
                    Credential               = $(Get-DryCredential -Alias "$($Action.credentials.credential2)" -EnvConfig "$($GLOBAL:EnvConfigName)")
                    SecondsToTry             = 300
                    SecondsToWaitBeforeStart = 30
                }
                $BuildStatus = Wait-DrySSH @WaitParameters
            }
            'windows' {
                $SessionConfig = $Configuration.connections | Where-Object { $_.type -eq 'winrm'} 
                if ($null -eq $SessionConfig) {
                    ol v "Unable to find 'connection' of type 'winrm' in environment config"
                    throw "Unable to find 'connection' of type 'winrm' in environment config"
                }
                $WaitParameters = @{
                    IP                       = $TargetVMIPAddress
                    Computername             = $Resource.name
                    Credential               = $(Get-DryCredential -Alias "$($Action.credentials.credential2)" -EnvConfig "$($GLOBAL:EnvConfigName)")
                    SecondsToTry             = 1800
                    SecondsToWaitBeforeStart = 200
                    SessionConfig            = $SessionConfig
                }
                $BuildStatus = Wait-DryWinRM @WaitParameters
            }
        }

        # Report build-status and terminate if failed
        switch ($BuildStatus) {
            $False {
                ol i 'Build Status',"FAILED"
                throw "Failed Build: $($Resource.name)"
            }
            $True {
                ol i 'Build Status',"SUCCESS"
            }  
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $VarsToRemove = @(
            'CredAlias',
            'Credentials',
            'PlatformProvider',
            'VMTemplate',
            'VMLayout',
            'VMDiskLayout',
            'OSCustomization',
            'NewVMSplat',
            'set_vm_splat',
            'DatastoreObject',
            'DatastoreRegex',
            'NetworkCustomization',
            'AdditionalDisks',
            'AdditionalDisk',
            'VirtualMachine',
            'WaitParameters',
            'BuildStatus'
        )
        $VarsToRemove.ForEach({
            Remove-Variable -Name "$_" -ErrorAction Ignore
        })
        Remove-Module -Name 'VMware*' -Force -ErrorAction Continue
        ol i "Action 'vsphere.clonevm' finished" -sh
    }
}