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

Function dry.action.win.reboot {
    [CmdletBinding()]  
    Param (
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
    Try {

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   OPTIONS
        #
        #   Resolve sources, temporary target folders, and other options 
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $OptionsObject       = Resolve-DryActionOptions -Resource $Resource -Action $Action -NoFiles
        $ConfigRootPath      = $OptionsObject.ConfigRootPath
        $MetaConfigFile      = Join-Path -Path $ConfigRootPath -ChildPath 'Config.json'
        
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   DEFAULT
        #
        #   The action does not require, but may have a metaconfig specifying the number 
        #   of reboots, and wether or not to do gpupdate. Spescify the defaults
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
        [Int]    $NumberOfReboots  = 1
        [Bool]   $GPUpdate         = $True
        [String] $ConfigOrDefault  = 'Default'

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   METACONFIG
        #
        #   The MetaConfig is a configfile with info about the config. If it exists, 
        #   expect the properties 'reboots' and 'gpupdate'. If not, use the default 
        #   defined previously
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
        If (Test-Path -Path $MetaConfigFile -ErrorAction Ignore) {
            [PSObject] $ActionMetaConfigObject = Get-DryFromJson -Path $MetaConfigFile -ErrorAction Stop 
            [Int]      $NumberOfReboots        = $ActionMetaConfigObject.reboots
            [Bool]     $GPUpdate               = $ActionMetaConfigObject.gpupdate
            [String]   $ConfigOrDefault        = 'Config'
        }
        
        Switch ($GPUpdate) {
            $True {
                $WithOrWithout = 'with'
            }
            Default {
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
        While ($Action.credentials."credential$CredCount") {
            $Credentials += @(Get-DryCredential -Alias $Action.credentials."credential$CredCount" -EnvConfig "$($GLOBAL:dry_var_global_ConfigCombo.envconfig.name)")
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
        $SessionConfig = $Configuration.connections | 
        Where-Object { 
            $_.type -eq 'winrm'
        }
        
        If ($Null -eq $SessionConfig) {
            ol w "Unable to find 'connection' of type 'winrm' in environment config"
            Throw "Unable to find 'connection' of type 'winrm' in environment config"
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   REBOOT LOOP
        #
        #   Run the loop $NumberOfReboot times
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #       
        
        For ($RebootCount = 1; $RebootCount -le $NumberOfReboots; $RebootCount++) {
            ol i @("Reboot $WithOrWithout GPUpdate","$RebootCount of $NumberOfReboots")
            
            If ($GPUpdate) {
                $InvokeInPSSessionParams = @{
                    Credential     = $Credentials
                    Command        = 'gpupdate' 
                    Computername   = $Resource.resolved_network.ip_address 
                    ArgumentString = '/force' 
                    SessionConfig  = $SessionConfig
                }
                ol i 'GPUpdate...'
                Invoke-DryInPSSession @InvokeInPSSessionParams
            }

            $InvokeInPSSessionParams = @{
                Command       = 'Restart-Computer' 
                Arguments     = @{'Force'=$True} 
                Credential    = $Credentials
                Computername  = $Resource.resolved_network.ip_address 
                SessionConfig = $SessionConfig
            }
            ol i 'Rebooting...'
            Invoke-DryInPSSession @InvokeInPSSessionParams
    
            $WaitWinRMInterfaceParams = @{
                IP                       = $Resource.resolved_network.ip_address
                Credential               = $Credentials
                ComputerName             = $Resource.name
                SecondsToTry             = 500
                SessionConfig            = $SessionConfig
                SecondsToWaitBeforeStart = 30
            }
    
            $WinRMStatus = Wait-DryWinRM @WaitWinRMInterfaceParams
            Switch ($WinRMStatus) {
                $False {
                    Throw "Failed to Connect to $($Resource.name) (IP: $($Resource.resolved_network.ip_address))"
                }
                $True {
                    ol i @('Successfully connected',"$($Resource.name) (IP: $($Resource.resolved_network.ip_address))")
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
        if ($null -ne $ActionMetaConfigObject.sleep_after_seconds) {
            Start-DryUtilsSleep -Seconds $ActionMetaConfigObject.sleep_after_seconds -Message "Sleeping $($ActionMetaConfigObject.sleep_after_seconds) seconds before continuing..."
        }
        ol i "All reboots were successful" -sh    
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
        @(  'ConfigRootPath',
            'NumberOfReboots',
            'GPUpdate',
            'ConfigOrDefault',
            'ActionMetaConfigObject',
            'WithOrWithout',
            'CredCount',
            'Credentials',
            'SessionConfig',
            'InvokeInPSSessionParams',
            'WaitWinRMInterfaceParams',
            'WinRMStatus'
        ).ForEach({
            Remove-Variable -Name $_ -ErrorAction Ignore
        })

        ol i "Action 'win.reboot' is finished" -sh
    }
}