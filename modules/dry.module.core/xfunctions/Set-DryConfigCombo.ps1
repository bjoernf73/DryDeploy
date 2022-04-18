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

#! what the hell is the meaning of this???????????????????????
function Set-DryConfigCombo {
    [cmdletbinding()]
    param (
        [PSObject] $RootConfig,
        [PSObject] $ConfigCombo,
        [String]   $Path
    )

    try {
        $ModuleType = $RootConfig.Type
        $ModuleType = $ModuleType.SubString(0,1).ToUpper() + $ModuleType.SubString(1).ToLower() 

        switch ($ModuleType) {
            'Environment' {
                $ThisConfig = $ConfigCombo.EnvConfig
            }
            'Module' {
                $ThisConfig = $ConfigCombo.ModuleConfig
            }
            '' {
                throw "Empty Configuration Repo type: $ModuleType"
            }
            default {
                throw "Unsupported Configuration Repo type: $ModuleType"
            }
        }

        if ($ThisConfig.Guid -ne $RootConfig.Guid) {
            ol w "$ModuleType Configuration changed:"
            ol w "Old Path:       '$($ThisConfig.Path)'"
            ol w "New Path:       '$Path'"
        }
        
        $ThisConfig.Description = $RootConfig.Description
        $ThisConfig.Guid = $RootConfig.Guid
        $ThisConfig.Type = $RootConfig.Type
        $ThisConfig.Path = $Path

        return $ConfigCombo
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
} 