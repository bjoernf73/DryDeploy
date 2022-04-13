<#
 This module is a string-pattern-in-object-propety-values replacement module 
 for use with DryDeploy
 
 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.pattern.replace/main/LICENSE
 
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

function Resolve-DryReplacementPattern {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String]$InputText,

        [Parameter(Mandatory)]
        [System.Collections.Generic.List[PSObject]]$Variables
    )
    
    foreach ($Variable in $Variables) {
        $Pattern = "###$($Variable.Name)###"
        if ($InputText -match $Pattern) {
            $Value = $Variable.Value 
            $InputText = $InputText -replace $Pattern,$Value
        }
    }
    return $InputText
}