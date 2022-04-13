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
function Get-DryADServiceProperty {
    [CmdletBinding(DefaultParameterSetName = 'Local')] 
    Param ( 
        [Parameter(Mandatory, HelpMessage = "The property to get")]
        [String] 
        $Property,

        [Parameter(Mandatory, HelpMessage = "Tells which function to run; Get-ADDomain, Get-ADForest or Get-ADRootDse")]
        [ValidateSet('domain', 'forest', 'rootdse')]
        [String] 
        $Service,

        [Parameter(Mandatory, ParameterSetName = 'Remote',
            HelpMessage = "PSSession to run the script blocks in")]
        [PSSession] 
        $PSSession,

        [Parameter(Mandatory, ParameterSetName = 'Local',
            HelpMessage = "For 'Local' sessions, specify the Domain Controller to use")]
        [String] 
        $DomainController
    )

    try {
        if ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $Server = 'localhost'
        }
        else {
            $Server = $DomainController
        }

        switch ($Service) {
            'domain' {
                $ScriptBlock = $DryAD_SB_ADDomainProperty_Get
            }
            'forest' {
                $ScriptBlock = $DryAD_SB_ADForestProperty_Get
            } 
            'rootdse' {
                $ScriptBlock = $DryAD_SB_ADRootDseProperty_Get
            }
        }
        
        $ArgumentList = @($Property, $Server)
        $InvokeParams = @{
            ScriptBlock  = $ScriptBlock
            ArgumentList = $ArgumentList
        }
        if ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $InvokeParams += @{
                Session = $PSSession
            }
        }
        $Return = $Null; 
        $Return = Invoke-Command @InvokeParams

        if ($Return -is [ErrorRecord]) {
            throw $Return
        }
        else {
            return $Return
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
