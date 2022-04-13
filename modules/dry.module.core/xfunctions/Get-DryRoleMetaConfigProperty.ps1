<# 
 This module provides core functionality for DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.core/main/LICENSE
 
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

function Get-DryRoleMetaConfigProperty {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSObject]
        $Configuration,

        [Parameter(Mandatory)]
        [String]
        $Role,

        [Parameter(Mandatory)]
        [String]
        $Property,

        [Parameter()]
        [Switch]
        $First,

        [Parameter()]
        [Switch]
        $Last
    )
    
    try {
        $RoleObject = $null
        $RoleObject = $Configuration.RoleMetaConfigs | Where-Object {
            $_.Role -eq "$Role"
        }
        if ($Null -eq $RoleObject) {
            throw "The role '$Role' was not found in this module"
        }

        if ($RoleObject."$Property") {
            if($First) {
                if (($RoleObject."$Property") -is [array]) {
                    return ($RoleObject."$Property")[0]
                }
                else {
                    return $RoleObject."$Property"
                }
            }
            elseif ($Last) {
                if (($RoleObject."$Property") -is [array]) {
                    return ($RoleObject."$Property")[-1]
                }
                else {
                    return $RoleObject."$Property"
                }
            }
            else {
                return $RoleObject."$Property"
            }
        }
        else {
            throw "The property '$Property' does not exist on Role '$Role'"
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        Remove-Variable -Name 'RoleObject' -ErrorAction Ignore | Out-Null
    }
}