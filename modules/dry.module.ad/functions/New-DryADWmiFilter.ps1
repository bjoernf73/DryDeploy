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
function New-DryADWmiFilter {
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    param (
        [Parameter(Mandatory, HelpMessage = 'The Name of the WMI Query')]
        [string]
        $Name,

        [Parameter(HelpMessage = 'Optional Description of the WMI Query')]
        [string]
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
        [string] 
        $DomainController
    )
    
    if ($PSCmdlet.ParameterSetName -eq 'Remote') {
        $Server = 'localhost'
        ol v @('Session Type', 'Remote')
        ol v @('Remoting to Domain Controller', $PSSession.ComputerName)
    }
    else {
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
        if ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $InvokeGetParams += @{
                Session = $PSSession
            }
        }
        $GetResult = Invoke-Command @InvokeGetParams

        switch ($GetResult) {
            $true {
                ol s 'WMI Filter exists already'
                ol v "The WMIFilter '$Name' exists already"
            }
            $false {
                ol v "The WMIFilter '$Name' does not exist, must be created"
            }
            default {
                ol w "Error trying to get WMIFilter '$Name'"
                throw $GetResult.ToString()
            }
        } 
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }  

    if ($GetResult -eq $false) {
        try {
            $SetArgumentList = @($Name, $Description, $Query, $Server)
            $InvokeSetParams = @{
                ScriptBlock  = $DryAD_SB_WMIFilter_Set
                ArgumentList = $SetArgumentList
                ErrorAction  = 'Stop'
            }
            if ($PSCmdlet.ParameterSetName -eq 'Remote') {
                $InvokeSetParams += @{
                    Session = $PSSession
                }
            }
            $SetResult = Invoke-Command @InvokeSetParams
            switch ($SetResult) {
                $true {
                    ol s "WMIFilter was created"
                    ol v "WMIFilter '$Name' was created"
                }
                default {
                    ol f "WMIFilter was not created"
                    throw $SetResult
                }
            } 
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}
