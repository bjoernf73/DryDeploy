Using NameSpace System.Management.Automation
Using NameSpace System.Management.Automation.Runspaces
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
function Move-DryADComputer {
    [CmdletBinding(DefaultParameterSetName = 'Local')] 
    param (
        [Parameter(Mandatory)]
        [string]
        $ComputerName,

        [Parameter(Mandatory)]
        [string]
        $TargetOU,

        [Parameter(HelpMessage = "Only test, and return true or false")]
        [Switch]
        $Test,

        [Parameter(Mandatory, ParameterSetName = 'Remote',
            HelpMessage = "PSSession to run the script blocks in")]
        [System.Management.Automation.Runspaces.PSSession] 
        $PSSession,

        [Parameter(Mandatory, ParameterSetName = 'Local',
            HelpMessage = "For 'Local' sessions, specify the Domain Controller to use")]
        [string] 
        $DomainController
    )
    ol v @("Moving: '$ComputerName' to OU", "$TargetOU")

    # Is the Object already in place??
    try {
        if ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $Server = 'localhost'
            $ExecutionType = 'Remote'
            ol v @('Session Type', 'Remote')
            ol v @('Remoting to Domain Controller', $PSSession.ComputerName)
        }
        else {
            $Server = $DomainController
            $ExecutionType = 'Local'
            ol v @('Session Type', 'Local')
            ol v @('Using Domain Controller', $Server)
        }

        $GetArgumentList = @($ComputerName, $TargetOU, $Server)
        $InvokeGetParams = @{
            ScriptBlock  = $DryAD_SB_MoveComputer_Get
            ArgumentList = $GetArgumentList
        }
        if ($ExecutionType -eq 'Remote') {
            $InvokeGetParams += @{
                Session = $PSSession
            }
        }
        $GetResult = Invoke-Command @InvokeGetParams 

        switch ($GetResult) {
            $true {
                ol s "Computer  is already in correct OU"
                ol v "'$ComputerName' is already in OU '$TargetOU'"
            }
            $false {
                ol v "'$ComputerName' is not in OU '$TargetOU' - trying to move it"
            }
            { $GetResult -is [System.Management.Automation.ErrorRecord] } {
                $PSCmdlet.ThrowTerminatingError($GetResult)
            }
            default {
                throw "An Error occured $($GetResult.ToString())"
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    if ($Test) {
        return $GetResult
    }
    elseif ($GetResult -eq $false) {
        try {     
            
            $SetArgumentList = @($ComputerName, $TargetOU, $Server)
            $InvokeSetParams = @{
                ScriptBlock  = $DryAD_SB_MoveComputer_Set
                ArgumentList = $SetArgumentList
            }
            if ($ExecutionType -eq 'Remote') {
                $InvokeSetParams += @{
                    Session = $PSSession
                }
            }
            $SetResult = Invoke-Command @InvokeSetParams

            switch ($SetResult) {
                $true {
                    ol s "Computer object was moved"
                    ol v "'$ComputerName' was moved into OU '$TargetOU'"
                }
                { $SetResult -is [System.Management.Automation.ErrorRecord] } {
                    $PSCmdlet.ThrowTerminatingError($SetResult)
                }
                default {
                    throw "An Error occured $($SetResult.ToString())"
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
