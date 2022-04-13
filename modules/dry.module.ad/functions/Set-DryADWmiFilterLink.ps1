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
Function Set-DryADWmiFilterLink {
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    Param (
        [Parameter(Mandatory)]
        [String]
        $GPOName,

        [Parameter(Mandatory)]
        [String]
        $WMIFilterName,

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

    try {
        # Test the existence of the GPO and the WMIFilter in AD
        [ScriptBlock]$TestADObjectScriptBlock = {
            Param (
                $Filter,
                $Server
            )
            try {
                $GetADObjectParams = @{
                    Filter      = $Filter
                    Server      = $Server
                    ErrorAction = 'Stop'
                    
                }
                $ADObject = $Null
                $ADObject = Get-ADObject @GetADObjectParams
                If ($Null -eq $ADObject) {
                    Throw "Object not found"
                }
                $True
            }
            Catch {
                Throw $_
            }
        }
    
        $Filters = @{
            GPO       = "(ObjectClass -eq 'groupPolicyContainer') -and (displayname -eq '$GPOName')"
            WMIFilter = "(ObjectClass -eq 'msWMI-Som') -and (msWMI-name -eq '$WMIFilterName')" 
        }
    
        $Filters.Keys.ForEach({
                $Filter = $Filters["$_"]
                ol v "Searching for filter", "$Filter"
                $TestArgumentList = @($Filters["$_"], $Server)
                $InvokeTestParams = @{
                    ScriptBlock  = $TestADObjectScriptBlock
                    ArgumentList = $TestArgumentList
                }
                If ($PSCmdlet.ParameterSetName -eq 'Remote') {
                    $InvokeTestParams += @{
                        Session = $PSSession
                    }
                }
                Switch (Invoke-Command @InvokeTestParams) {
                    $True {
                        ol v "Verified that '$Filter' returned an object from AD"
                    }
                    Default {
                        ol v "Failed get '$Filter' in AD"
                        Throw $_
                    }
                }
            })

        # If we reached here, the GPO and WMI Filter exist
        [ScriptBlock]$SetScriptBlock = {
            Param (
                $GPOName,
                $WMIFilterName,
                $Server
            )
            try {
                
                $DomainFQDN = (Get-ADDomain -Server $Server -ErrorAction Stop).DnsRoot
                $GetGPOParams = @{
                    Filter      = "(ObjectClass -eq 'groupPolicyContainer') -and (displayname -eq '$GPOName')"
                    Properties  = @('gPCWQLFilter', 'ObjectClass')
                    Server      = $Server
                    ErrorAction = 'Stop'
                }
                $GPOADObject = Get-ADObject @GetGPOParams

                $GetWMIFilterParams = @{
                    Filter      = "(ObjectClass -eq 'msWMI-Som') -and (msWMI-name -eq '$WMIFilterName')"
                    Properties  = @('CN', 'msWMI-name', 'ObjectClass')
                    Server      = $Server
                    ErrorAction = 'Stop'
                }
                $WMIFilterADObject = Get-ADObject @GetWMIFilterParams
                $gPCWQLFilter = "[$DomainFQDN;$($WMIFilterADObject.CN);0]"

                $SetParams = @{
                    Server      = $Server
                    ErrorAction = 'Stop'
                }
                If ($Null -eq $GPOADObject.gPCWQLFilter) {
                    $SetParams += @{
                        Add = @{gPCWQLFilter = $gPCWQLFilter }
                    }
                }
                Else {
                    $SetParams += @{
                        Replace = @{gPCWQLFilter = $gPCWQLFilter }
                    }
                }

                $GPOADObject | Set-ADObject @SetParams | Out-Null
                $True
            }
            Catch {
                Throw $_
            }
        }
        $SetArgumentList = @($GPOName, $WMIFilterName, $Server)
        $InvokeSetParams = @{
            ScriptBlock  = $SetScriptBlock
            ArgumentList = $SetArgumentList
        }
        If ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $InvokeSetParams += @{
                Session = $PSSession
            }
        }
        $SetResult = Invoke-Command @InvokeSetParams

        Switch ($SetResult) {
            $True {
                ol s "WMIFilter applied to GPO"
                ol v "The WMIFilter '$WMIFilterName' was applied to GPO '$GPOName'"
            }
            Default {
                ol f "WMIFilter not applied to GPO"
                ol e "The WMIFilter '$WMIFilterName' was not applied to GPO '$GPOName': $($SetResult.ToString())"
                Throw $SetResult.ToString()
            }
        }
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

