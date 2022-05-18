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

function Get-DryEnvConfig {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$ConfigCombo,

        [Parameter(Mandatory)]
        [PSCustomObject]$Paths
    )
    try {
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        
            EnvConfig

            The EnvConfig describes the environment into which you deploy your module. The EnvConfig 
            is a directory or repository containing three sub directories; 
            
            1. 'CoreConfig' which containing configurations DryDeploy needs to Plan and Apply

            2. 'UserConfig' which is user definable. Make any structure you'd like, and resolve in 
                params to your Actions

            3. 'OSConfig' has a file structure like Roles, but lacks Phases. We don't "pick up" those 
                configs here, since they may be DSC-files, Active Directory defintions, and such - 
                just record the path to the folder. Actions that inherit OSConfigs, will pick those
                files up, and include in your Action config.

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        $Configuration = $null
        $Configuration = [PSCustomObject]@{
            CoreConfig = $null 
            UserConfig = $null
            Paths = $Paths
        }
        $Configuration.CoreConfig = Get-DryConfigData -Path (Join-Path -Path $ConfigCombo.envconfig.path -ChildPath 'CoreConfig') -ErrorAction Stop
        if (Test-Path -Path (Join-Path -Path $ConfigCombo.envconfig.path -ChildPath 'UserConfig')) {
            $Configuration.UserConfig = Get-DryConfigData -Path (Join-Path -Path $ConfigCombo.envconfig.path -ChildPath 'UserConfig') -Configuration $Configuration -ErrorAction Stop
        }
        return $Configuration
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}