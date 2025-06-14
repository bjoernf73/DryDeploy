<# 
 This module provides query functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.query/main/LICENSE
 
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

<#
.SYNOPSIS
Tests if Config AD execution type should be Remote or Local 

.DESCRIPTION
Queries if all prerequisites for a local execution is met and 
returns 'Local' if they are, else returns 'Remote'
   
.PARAMETER Configuration
The full $Configuration 

#>
function Get-DryAdExecutionType{
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Configuration
    )
    
    $LocalPrereqs = @{
        DomainComputer               = $false
        DomainComputerInTargetDomain = $false
        ADModuleInstalled            = $false
        GPOModuleInstalled           = $false
    }
    
    try{
        if($PSVersionTable.PSEdition -eq 'Core'){
            if($PSVersionTable.Platform -ne 'Win32NT'){
                ol v "Running on non-Windows - returning 'Remote'"
                return 'Remote'
            }
        }
                
        $LocalPrereqs['DomainComputer'] = $false
        $LocalPrereqs['DomainComputerInTargetDomain'] = $false
        $LocalPrereqs['ADModuleInstalled'] = $false
        $LocalPrereqs['GPOModuleInstalled'] = $false
       
        # Test: If executing system is in a domain and that domain is our target
        if((Get-CimInstance -Class Win32_ComputerSystem -ErrorAction SilentlyContinue).PartOfDomain){
            $LocalPrereqs['DomainComputer'] = $true
        }

        # Test: If executing system is in target domain
        if((Get-CimInstance -Class Win32_ComputerSystem -ErrorAction SilentlyContinue).Domain -eq $Configuration.CoreConfig.network.domain.domain_fqdn){
            $LocalPrereqs['DomainComputerInTargetDomain'] = $true
        }

        # Test: If the ActiveDirectory module is installed
        if(Get-Module -ListAvailable -Name 'ActiveDirectory'){
            $LocalPrereqs['ADModuleInstalled'] = $true
        }
        # Test: If the GroupPolicy module is installed
        if(Get-Module -ListAvailable -Name 'GroupPolicy'){
            $LocalPrereqs['GPOModuleInstalled'] = $true
        }

        ol v "Local/Remote Execution prerequisites hash below..."
        ol v -hash $LocalPrereqs

        # Loop through all
        $LocalPrereqs.Keys | foreach-Object{
            if($LocalPrereqs["$_"] -eq $false){
                return 'Remote'
            }
        }
        return "Local"
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}