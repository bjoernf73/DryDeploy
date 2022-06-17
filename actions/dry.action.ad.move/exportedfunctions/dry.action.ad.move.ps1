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

function dry.action.ad.move { 
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
        $MetaConfig = $Resolved.ActionMetaConfig
        $RoleOUType = $Resolved.ActionType
        $RoleOU = $MetaConfig.ous."$RoleOUType"
        
        if ($null -eq $RoleOU) {
            throw "Action does not contain an OU of type '$RoleOUType'"
        }
        # Replace replacement patterns                             
        $RoleOU = Resolve-DryReplacementPattern -InputText "$RoleOU" -Variables $Resolved.vars
        
        # Convert the RoleOU to a distinguished name
        $RoleOU = ConvertTo-DryUtilsDistinguishedName -Name $RoleOU
        ol i @("The resolved role OU distinguishedName","$RoleOU")
        
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #   Credential
        #   Action: Get Credential for the Action
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        $Credential = $Resolved.Credentials.credential1
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
            Resource      = $Action.Resource 
            Configuration = $Configuration 
            ExecutionType = $ExecutionType
        }
        if ($ExecutionType -eq 'Remote') {
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
        if ($ExecutionType -eq 'Remote') {
            # Create the session
            $SessionConfig = $Configuration.CoreConfig.connections | 
            Where-Object { 
                $_.type -eq 'winrm'
            }
            if ($null -eq $SessionConfig) {
                throw "Unable to find 'connection' of type 'winrm' in environment config"
            }

            $GetDrySessionParams =  @{
                ComputerName  = $ActiveDirectoryConnectionPoint
                Credential    = $Credential
                SessionConfig = $SessionConfig
                SessionType   = 'PSSession'
            }
            $AdMoveSession = New-DrySession @GetDrySessionParams
            ol i @("Created PSSession to connection point","Session ID: $($AdMoveSession.Id), State: $($AdMoveSession.State)")
        }

        $MoveDryADComputerParams = @{
            ComputerName = $Action.Resource.Name
            TargetOU     = $RoleOU
        }
        switch ($ExecutionType) {
            'Remote' {
                $MoveDryADComputerParams += @{
                    PSSession = $AdMoveSession       
                }
            }
            'Local' {
                $MoveDryADComputerParams += @{
                    DomainController = $ActiveDirectoryConnectionPoint       
                }
            }
        }

        ol i @("Moving '$($Action.Resource.name)' computer object to","$RoleOU")
        Move-DryADComputer @MoveDryADComputerParams

        ol i "Sleeping 10 seconds before testing the new state"
        Start-Sleep -Seconds 10

        $MoveDryADComputerParams+= @{'Test'=$True}
        ol i @("Testing location of '$($Action.Resource.name)' computer object","$RoleOU")
        
        if ((Move-DryADComputer @MoveDryADComputerParams) -eq $True) {
            ol i "Successfully completed the MoveToOU Action"
        }
        else {
            throw "Failed Action MoveToOU"
        }        
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $AdMoveSession | Remove-PSSession -ErrorAction Ignore 
        Remove-Module -Name 'dry.module.ad' -Force -ErrorAction continue
        ol i "Action 'ad.move' is finished" -sh
    }
}