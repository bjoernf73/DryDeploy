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
function Set-DryADWmiFilterLink {
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    param (
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

    try {
        # Test the existence of the GPO and the WMIFilter in AD
        [ScriptBlock]$TestADObjectScriptBlock = {
            param (
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
                if ($Null -eq $ADObject) {
                    throw "Object not found"
                }
                $true
            }
            catch {
                throw $_
            }
        }
    
        $Filters = @{
            GPO       = "(ObjectClass -eq 'groupPolicyContainer') -and (displayname -eq '$GPOName')"
            WMIFilter = "(ObjectClass -eq 'msWMI-Som') -and (msWMI-name -eq '$WMIFilterName')" 
        }
    
        $Filters.Keys.foreach({
                $Filter = $Filters["$_"]
                ol v "Searching for filter", "$Filter"
                $TestArgumentList = @($Filters["$_"], $Server)
                $InvokeTestParams = @{
                    ScriptBlock  = $TestADObjectScriptBlock
                    ArgumentList = $TestArgumentList
                }
                if ($PSCmdlet.ParameterSetName -eq 'Remote') {
                    $InvokeTestParams += @{
                        Session = $PSSession
                    }
                }
                switch (Invoke-Command @InvokeTestParams) {
                    $true {
                        ol v "Verified that '$Filter' returned an object from AD"
                    }
                    default {
                        ol v "Failed get '$Filter' in AD"
                        throw $_
                    }
                }
            })

        # If we reached here, the GPO and WMI Filter exist
        [ScriptBlock]$SetScriptBlock = {
            param (
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
                if ($Null -eq $GPOADObject.gPCWQLFilter) {
                    $SetParams += @{
                        Add = @{gPCWQLFilter = $gPCWQLFilter }
                    }
                }
                else {
                    $SetParams += @{
                        Replace = @{gPCWQLFilter = $gPCWQLFilter }
                    }
                }

                $GPOADObject | Set-ADObject @SetParams | Out-Null
                $true
            }
            catch {
                throw $_
            }
        }
        $SetArgumentList = @($GPOName, $WMIFilterName, $Server)
        $InvokeSetParams = @{
            ScriptBlock  = $SetScriptBlock
            ArgumentList = $SetArgumentList
        }
        if ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $InvokeSetParams += @{
                Session = $PSSession
            }
        }
        $SetResult = Invoke-Command @InvokeSetParams

        switch ($SetResult) {
            $true {
                ol s "WMIFilter applied to GPO"
                ol v "The WMIFilter '$WMIFilterName' was applied to GPO '$GPOName'"
            }
            default {
                ol f "WMIFilter not applied to GPO"
                ol e "The WMIFilter '$WMIFilterName' was not applied to GPO '$GPOName': $($SetResult.ToString())"
                throw $SetResult.ToString()
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

