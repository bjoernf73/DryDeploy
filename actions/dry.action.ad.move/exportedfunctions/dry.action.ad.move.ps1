# This module is an action module for use with DryDeploy. It moves a computer 
# object in AD using the dry.module.ad module
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.ad.move/main/LICENSE
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

Function dry.action.ad.move {
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
        $OptionsObject       = Resolve-DryActionOptions -Resource $Resource -Action $Action
        $ActionType          = $OptionsObject.ActionType
        $ConfigRootPath      = $OptionsObject.ConfigRootPath
        $MetaConfigFile      = Join-Path -Path $ConfigRootPath -ChildPath 'Config.json'
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   METACONFIG
        #
        #   Open MetaConfig, resolve OU from it
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        
        $MetaConfig          = Get-DryFromJson -File $MetaConfigFile
        $RoleOU              = $MetaConfig.ous."$ActionType"
        If ($Null -eq $RoleOU) {
            ol -t 1 -m "Action does not contain an OU of type '$ActionType'"
            Throw "Action does not contain an OU of type '$ActionType'"
        }
        # Replace replacement patterns
        $RoleOU = Resolve-DryReplacementPattern -InputText $RoleOU -Variables $ResourceVariables
        
        # Convert the RoleOU to a distinguished name
        $RoleOU = ConvertTo-DryUtilsDistinguishedName -Name $RoleOU
        ol i @("The resolved role OU distinguishedName","$RoleOU")
        
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #   Credential
        #   Action: Get Credential for the Action
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        $Credential = Get-DryCredential -Alias "$($action.credentials.credential1)"  -EnvConfig $GLOBAL:dry_var_global_ConfigCombo.envconfig.name
        ol i @('Using Credential',"$($Credential.UserName)")

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #  Execution Type 
        # 
        #  In a Greenfield deployment, this is running an a computer outside the domain
        #  and we must remote into a domain controller to execute each configuration
        #  action. However, if this is running on a domain member in that domain, we
        #  assume that the config  may run locally. The DryAD module supports both 
        #  'Local' and 'Remote' execution. The Get-DryAdExecutionType query function
        #  tests if the prerequisites for a Local execution is there
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        Enum ExecutionType { Local; Remote }        
        [ExecutionType]$ExecutionType = Get-DryAdExecutionType -Configuration $Configuration
        ol i 'Execution Type',$ExecutionType

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   Resolve Active Directory Connection Point
        #
        #   Should be able to connect to the first available of an array
        #   of preferred connection points for the site that the resource belongs to 
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $GetDryADConnectionPointParams = @{
            Resource      = $Resource 
            Configuration = $Configuration 
            ExecutionType = $ExecutionType
        }
        If ($ExecutionType -eq 'Remote') {
            $GetDryADConnectionPointParams += @{
                Credential    = $Credential
            }
        }
        
        $ActiveDirectoryConnectionPoint = Get-DryADConnectionPoint @GetDryADConnectionPointParams
        ol i @('Connection Point (Domain Controller)',$ActiveDirectoryConnectionPoint)

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #   PSSESSION
        #   Action: Create session
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        If ($ExecutionType -eq 'Remote') {
            # Create the session
            $SessionConfig = $Configuration.connections | 
            Where-Object { 
                $_.type -eq 'winrm'
            }
            If ($Null -eq $SessionConfig) {
                ol v "Unable to find 'connection' of type 'winrm' in environment config"
                Throw "Unable to find 'connection' of type 'winrm' in environment config"
            }

            $GetDrySessionParams =  @{
                ComputerName  = $ActiveDirectoryConnectionPoint
                Credential    = $Credential
                SessionConfig = $SessionConfig
                SessionType   = 'PSSession'
            }
            $ConfADSession = New-DrySession @GetDrySessionParams

            ol i @("Created PSSession to connection point","Session ID: $($ConfADSession.Id), State: $($ConfADSession.State)")
        }

        $MoveDryADComputerParams = @{
            ComputerName = $Resource.Name
            TargetOU     = $RoleOU
        }
        Switch ($ExecutionType) {
            'Remote' {
                $MoveDryADComputerParams += @{
                    PSSession = $ConfADSession       
                }
            }
            'Local' {
                $MoveDryADComputerParams += @{
                    DomainController = $ActiveDirectoryConnectionPoint       
                }
            }
        }

        ol i @("Moving '$($Resource.name)' computer object to","$RoleOU")
        Move-DryADComputer @MoveDryADComputerParams

        ol i "Sleeping 10 seconds before testing the new state"
        Start-Sleep -Seconds 10

        $MoveDryADComputerParams+= @{'Test'=$True}
        ol i @("Testing location of '$($Resource.name)' computer object","$RoleOU")
        
        If ((Move-DryADComputer @MoveDryADComputerParams) -eq $True) {
            ol i "Successfully completed the MoveToOU Action"
        }
        Else {
            Throw "Failed Action MoveToOU"
        }        
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
        $ConfADSession | Remove-PSSession -ErrorAction Ignore
        $VarsToRemove = @(
            'RoleOU',
            'Credential',
            'ActiveDirectoryConnectionPoint',
            'GetDrySessionParams',
            'ConfADSession',
            'MoveDryADComputerParams',
            'Test'
        )
        $VarsToRemove.ForEach({
            Remove-Variable -Name "$_" -ErrorAction Ignore
        })
        Remove-Module -Name 'dry.module.ad' -Force -ErrorAction Continue
        ol i "Action 'ad.move' is finished" -sh
    }
}