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

function Get-DryVMIPAddress {
    [CmdletBinding()]  
    param (
        [Parameter(Mandatory, HelpMessage="Name (resolvable URL) of 
        the vCenter to connect to")]
        [String]
        $vCenter,

        [Parameter(Mandatory, HelpMessage="Credential with which you 
        are allowed to connect to your vCenter")]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter(Mandatory, HelpMessage="Name of the VM guest")]
        [String]$VMName,

        [Parameter(HelpMessage="How long (in seconds) do you want
        me to try getting the VMs IP? Default is 180 (3 minutes)")]
        [Int] $SecondsToTry = 180,

        [Parameter(HelpMessage="How long (in seconds) do you want
        me to wait before I start? By default, I wait 15 seconds")]
        [Int] $SecondsToWaitBeforeStart = 15,

        [Parameter(HelpMessage="How long (in seconds) do you want
        me to wait between each retry? By default, I wait 15 seconds")]
        [Int] $SecondsToWaitBetweenTries = 60
    )
    try {
        ol i "Getting IP of VM $VMName" -sh
        # Wait a number of seconds before searching
        for ($Timer = 1; $Timer -lt $SecondsToWaitBeforeStart; $Timer++) {
            $WriteProgressParameters = @{
                Activity        = "Getting IP of VM $VMName"
                Status          = "Waiting $($SecondsToWaitBeforeStart-$Timer) seconds before starting"
                PercentComplete = (($Timer / $SecondsToWaitBeforeStart) * 100 )   
            }
            Write-Progress @WriteProgressParameters
            Start-Sleep -seconds 1
        }
        Write-Progress -Completed -Activity "Getting IP of VM $VMName"
        
        # Connect to the vCenter
        $vCenterConnection = Connect-DryVIServer -vCenter $vCenter -Credential $Credential

        # Define the timespan within which we will keep searching
        $StartTime = Get-Date
        [datetime]$TargetTime = (Get-Date).AddSeconds($SecondsToTry)
        ol i 'Searching until',"$TargetTime"

        [bool]$IPFound = $false

        do {
            $ProgressTotalTime = [Int]((New-TimeSpan -Start $StartTime -End $TargetTime).TotalSeconds)
            $ProgressTotalTime = [Int]((New-TimeSpan -Start $StartTime -End $TargetTime).TotalSeconds)
            $ProgressTimeLeft = [Int]((New-TimeSpan -Start (Get-Date) -end $TargetTime).TotalSeconds)
            $WriteProgressParameters = @{
                Activity        = "Getting IP of VM $VMName"
                Status          = "Searching..."
                PercentComplete = ((($ProgressTotalTime-$ProgressTimeLeft) / $ProgressTotalTime) * 100 )   
            }   
            Write-Progress @WriteProgressParameters    
            try {
                $IPAddress = (Get-VMGuest -VM (Get-VM -Name "$VMName" -Server "$vCenter" -ErrorAction SilentlyContinue)).IPAddress[0]
                if ($IPAddress) {
                    [bool]$IPFound = $true
                }
            }
            catch {
                Start-Sleep -Seconds 10
            }
        }
        while (($IPFound -eq $False) -and ((Get-Date) -lt $TargetTime))
        if ($IPAddress) {
            ol i "IP of VM $VMName","$IPAddress"
            return $IPAddress
        }
        else {
            ol e "IP of VM $VMName",'not found'
            throw "IP of VM $VMName was not found within timeframe of $SecondsToTry seconds"
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        if ($vCenterConnection) {
            Disconnect-DryVIServer -VIConnection $vCenterConnection | Out-Null
        }
    }
}