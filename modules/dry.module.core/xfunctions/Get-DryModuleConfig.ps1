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

function Get-DryModuleConfig {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$ConfigCombo,

        [Parameter(Mandatory,HelpMessage="Object to merge changes into")]
        [PSCustomObject]$Configuration
    )
    try {
        # Mandatory Module Configuration directories
        @($ConfigCombo.moduleconfig.rolespath,$ConfigCombo.moduleconfig.buildpath).Foreach({
            try {
                Test-Path -Path $_ -ErrorAction Stop | Out-Null
            }
            catch {
                throw "Module is missing mandatory directory '$_'"
            }
        })

        $Configuration = Get-DryConfigData -Path $ConfigCombo.moduleconfig.buildpath -Configuration $Configuration
        $Configuration | Add-Member -MemberType NoteProperty -name ModuleConfigDirectory -value $ConfigCombo.moduleconfig.path

        # Each folder below $ConfigCombo.moduleconfig.rolespath should have a Config.Json containing
        # meta properties for the Roles. Pick up and create a an array RoleMetaConfigs, and add to the configuration. 
        $RoleConfigFolders = Get-ChildItem -Path $ConfigCombo.moduleconfig.rolespath -Attributes Directory -ErrorAction Stop
        $COObjects = @()
        $RoleConfigFolders.foreach({
            $COObject = New-Object -TypeName PSObject 
            $COObjectJson = Get-DryFromJson -Path (Join-Path -Path $_.FullName -ChildPath 'Config.json')
            $COObjectJson.PSObject.Properties.Foreach({
                $COObject | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value
            })
            $COObjects+=$COObject
        })
        $Configuration | Add-Member -MemberType NoteProperty -Name RoleMetaConfigs -Value $COObjects

        # Credentials 
        if (Test-Path -Path $ConfigCombo.moduleconfig.credentialspath) {
            $Configuration = Get-DryConfigData -Path $ConfigCombo.moduleconfig.credentialspath -Configuration $Configuration
        }
        return $Configuration
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}