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
Gets a named variable value from $Variables 

.DESCRIPTION
Variables is a (System.Collections.Generic.)List of PSObjects
with a name and value property. You pass in $Variables and the
name, I return the value 
   
.PARAMETER Variables
The [System.Collections.Generic.List] containing [PSObject]s
with a name and a value property 

.EXAMPLE
Get-DryVariableValue -Variables $Variables -Name DomainNB
Returns the value property of the PSObject in $Variables 
that has a .name property of 'DomainNB' 
#>
function Get-DryVariableValue {
    param (
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[PSObject]]$Variables,

        [Parameter(HelpMessage="The variable name to get from `$Variables")]
        [String]$Name
    )
    
    try {
        Remove-Variable -Name Variable -ErrorAction Ignore
        $Variable = $Variables | Where-Object {
            $_.Name -eq $Name
        }
        if ($Null -eq $Variable) {
            ol w "Variables does not contain a variable named '$Name'"
            throw "Variables does not contain a variable named '$Name'"
        }
        elseif ($Variable -is [Array]) {
            ol w "Variables contains multiple variables named '$Name'"
            throw "Variables contains multiple variables named '$Name'"
        }
        else {
            return $Variable.Value
        } 
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}