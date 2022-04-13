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
Function New-DryADWmiFilter {
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    Param (
        [Parameter(Mandatory, HelpMessage = 'The Name of the WMI Query')]
        [String]
        $Name,

        [Parameter(HelpMessage = 'Optional Description of the WMI Query')]
        [String]
        $Description,
    
        [Parameter(Mandatory, HelpMessage = 'The WMI Query itself')]
        [String[]]
        $Query,
    
        [Parameter(Mandatory, ParameterSetName = 'Remote', HelpMessage = "PSSession 
        to run the script blocks in if Remote execution")]
        [PSSession] 
        $PSSession,

        [Parameter(Mandatory, ParameterSetName = 'Local', HelpMessage = "Specify the 
        Domain Controller to target in Local Session")]
        [String] 
        $DomainController
    )
    
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
   
    # Test if object exists. Currently does not  
    # test the content, only if it exists or not
    try {
        $GetArgumentList = @($Name, $Server)
        $InvokeGetParams = @{
            ScriptBlock  = $DryAD_SB_WMIFilter_Get
            ArgumentList = $GetArgumentList
        }
        If ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $InvokeGetParams += @{
                Session = $PSSession
            }
        }
        $GetResult = Invoke-Command @InvokeGetParams

        Switch ($GetResult) {
            $True {
                ol s 'WMI Filter exists already'
                ol v "The WMIFilter '$Name' exists already"
            }
            $False {
                ol v "The WMIFilter '$Name' does not exist, must be created"
            }
            Default {
                ol w "Error trying to get WMIFilter '$Name'"
                Throw $GetResult.ToString()
            }
        } 
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }  

    If ($GetResult -eq $False) {
        try {
            $SetArgumentList = @($Name, $Description, $Query, $Server)
            $InvokeSetParams = @{
                ScriptBlock  = $DryAD_SB_WMIFilter_Set
                ArgumentList = $SetArgumentList
                ErrorAction  = 'Stop'
            }
            If ($PSCmdlet.ParameterSetName -eq 'Remote') {
                $InvokeSetParams += @{
                    Session = $PSSession
                }
            }
            $SetResult = Invoke-Command @InvokeSetParams
            Switch ($SetResult) {
                $True {
                    ol s "WMIFilter was created"
                    ol v "WMIFilter '$Name' was created"
                }
                Default {
                    ol f "WMIFilter was not created"
                    Throw $SetResult
                }
            } 
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
