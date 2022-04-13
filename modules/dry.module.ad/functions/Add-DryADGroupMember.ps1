Using Namespace System.Management.Automation
Using Namespace System.Management.Automation.Runspaces
<#  
    This is an AD Config module for use with DryDeploy, or by itself.
    Copyright (C) 2021  Bjørn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.ad/main/LICENSE

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#>

Function Add-DryADGroupMember {
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    Param (
        [Parameter(Mandatory, HelpMessage = "The Group to add the Member to")]
        [String] 
        $Group,

        [Parameter(Mandatory, HelpMessage = "The Member to add the Group")]
        [String] 
        $Member,

        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [PSSession] 
        $PSSession,

        [Parameter(Mandatory, ParameterSetName = 'Local',
            HelpMessage = "For 'Local' sessions, specify the Domain Controller to use")]
        [String] 
        $DomainController
    )
    ol d @("Adding: $Member to", $Group)
    
    <#
        If executing on a remote session to a DC, use localhost as  
        server. If not, the $DomainController param is required
    #>
    If ($PSCmdlet.ParameterSetName -eq 'Remote') {
        $Server = 'localhost'
        ol v @('Session Type', 'Remote')
        ol v @('Remoting to Domain Controller', $PSSession.ComputerName)
    }
    Else {
        $Server = $DomainController
        ol v @('Session Type', 'Local')
        ol v @('Using Domain Controller', $Server)
    }

    Try {     
        $GetArgumentList = @($Group, $Member, $Server)
        $GetParams = @{
            ScriptBlock  = $DryAD_SB_GroupMember_Get
            ArgumentList = $GetArgumentList
        }
        If ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $GetParams += @{
                Session = $PSSession
            }
        }
        $GetResult = Invoke-Command @GetParams

        Switch ($GetResult) {
            $True {
                ol v @("$Member is already member of", "$Group")
                ol s "Already member"
                Return
            }
            $False {
                ol v @("$Member will be added to", "$Group")
            }
            { $GetResult -is [System.Management.Automation.ErrorRecord] } {
                $PSCmdlet.ThrowTerminatingError($GetResult)
            }
            Default {
                Throw "GetResult in Add-DryADGroupMember failed: $($GetResult.ToString())"
            }
        }
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
 
    Try {     
        $SetArgumentList = @($Group, $Member, $Server)
        $SetParams = @{
            ScriptBlock  = $DryAD_SB_GroupMember_Set
            ArgumentList = $SetArgumentList
        }
        If ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $SetParams += @{
                Session = $PSSession
            }
        }
        $SetResult = Invoke-Command @SetParams 

        Switch ($SetResult) {
            $True {
                ol s "Member added to Group"
                ol v @("$Member was added to Group", $Group)
            }
            { $SetResult -is [ErrorRecord] } {
                ol f "Member not added to Group"
                $PSCmdlet.ThrowTerminatingError($GetResult)
            }
            Default {
                ol f "Member not added to Group"
                Throw "SetResult in Add-DryADGroupMember failed: $($GetResult.ToString())"
            }
        }
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }  
}
