# This module is an action module for use with DryDeploy. It reboots a 
# windows machine
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.win.reboot/main/LICENSE
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

function dry.action.win.reboot {
    [CmdletBinding()]  
    param (
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
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   DEFAULT
        #
        #   The action does not require, but may have a metaconfig specifying the number 
        #   of reboots, and wether or not to do gpupdate. Spescify the defaults
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
        [int]    $NumberOfReboots  = 1
        [Bool]   $GPUpdate         = $true
        [string] $ConfigOrDefault  = 'Default'

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   METACONFIG
        #
        #   The MetaConfig is a configfile with info about the config. If it exists, 
        #   expect the properties 'reboots' and 'gpupdate'. If not, use the default 
        #   defined previously
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
        if ($Resolved.ActionMetaConfig) {
            [int]$NumberOfReboots = $Resolved.ActionMetaConfig.reboots
            [Bool]$GPUpdate = $Resolved.ActionMetaConfig.gpupdate
            [string]$ConfigOrDefault        = 'Config'
        }
        
        switch ($GPUpdate) {
            $true {
                $WithOrWithout = 'with'
            }
            default {
                $WithOrWithout = 'without'
            }
        }
        ol i "Rebooting $NumberOfReboots time(s) $WithOrWithout GPUpdate ($ConfigOrDefault)" -sh

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   CREDENTIAL
        #
        #   The GPUpdate may enforce settings that require a different credential
        #   to be used after the reboot - the restart Action will just alternate
        #   between them and use whichever works
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $CredCount = 1
        while ($Resolved.credentials."credential$CredCount") {
            $Credentials += @($Resolved.credentials."credential$CredCount")
            $CredCount++
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   SESSION
        #
        #   The action uses a PSSession to connect. After the (optional) gpupdate and 
        #   reboot, it reuses the credential(s) to create a new session just to verify
        #   that the target is up and reachable
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        
        # get the winrm session options
        $SessionConfig = $Configuration.CoreConfig.connections | 
        Where-Object { 
            $_.type -eq 'winrm'
        }
        
        if ($null -eq $SessionConfig) {
            throw "Unable to find 'connection' of type 'winrm' in environment config"
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   REBOOT LOOP
        #
        #   Run the loop $NumberOfReboot times
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #       
        
        for ($RebootCount = 1; $RebootCount -le $NumberOfReboots; $RebootCount++) {
            ol i @("Reboot $WithOrWithout GPUpdate","$RebootCount of $NumberOfReboots")
            
            if ($GPUpdate) {
                $InvokeInPSSessionParams = @{
                    Credential     = $Credentials
                    Command        = 'gpupdate' 
                    Computername   = $Action.Resource.resolved_network.ip_address 
                    ArgumentString = '/force' 
                    SessionConfig  = $SessionConfig
                }
                ol i 'GPUpdate...'
                Invoke-DryInPSSession @InvokeInPSSessionParams
            }

            $InvokeInPSSessionParams = @{
                Command       = 'Restart-Computer' 
                Arguments     = @{'Force'=$true} 
                Credential    = $Credentials
                Computername  = $Action.Resource.resolved_network.ip_address 
                SessionConfig = $SessionConfig
            }
            ol i 'Rebooting...'
            Invoke-DryInPSSession @InvokeInPSSessionParams
    
            $WaitWinRMInterfaceParams = @{
                IP                       = $Action.Resource.resolved_network.ip_address
                Credential               = $Credentials
                ComputerName             = $Action.Resource.name
                SecondsToTry             = 500
                SessionConfig            = $SessionConfig
                SecondsToWaitBeforeStart = 30
            }
    
            $WinRMStatus = Wait-DryWinRM @WaitWinRMInterfaceParams
            switch ($WinRMStatus) {
                $false {
                    throw "Failed to Connect to $($Action.Resource.name) (IP: $($Action.Resource.resolved_network.ip_address))"
                }
                $true {
                    ol i @('Successfully connected',"$($Action.Resource.name) (IP: $($Action.Resource.resolved_network.ip_address))")
                }  
            }
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   SLEEP AFTER 
        #
        #   Sleeps the configured number of secons (.sleep_after_seconds) to let services 
        #   on the restartet resource come up
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #   
        if ($null -ne $Resolved.ActionMetaConfig.sleep_after_seconds) {
            Start-DryUtilsSleep -Seconds $Resolved.ActionMetaConfig.sleep_after_seconds -Message "Sleeping $($Resolved.ActionMetaConfig.sleep_after_seconds) seconds before continuing..."
        }
        ol i "All reboots were successful" -sh    
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        @(Get-Variable -Scope Script).foreach({
            Remove-Variable -Name $_ -ErrorAction Ignore
        })

        ol i "Action 'win.reboot' is finished" -sh
    }
}