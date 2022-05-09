<# 
 This module provides core functionality for DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
 
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

function Get-DryConfigCombo {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(Mandatory)]
        [PSCustomObject]$SystemOptions,

        [Parameter(Mandatory)]
        [PSCustomObject]$Platform
    )
    try {
        $SystemDependencies = $SystemOptions.dependencies."$($Platform.platform)"."$($Platform.edition)"
        # Create the PSCustomObject 
        $ConfigCombo = [PSCustomObject]@{
            name                     = 'default'
            path                     = "$Path"
            platform                 = $Platform.platform
            edition                  = $Platform.edition
            envconfig                = [PSCustomObject]@{ name = ''; type = 'environment';  guid = ''; path = $null; description = ''; dependencies_hash = ''; dependencies = $null; configpath = $null; osconfigpath = $null}
            moduleconfig             = [PSCustomObject]@{ name = ''; type = 'module';       guid = ''; path = $null; description = ''; dependencies_hash = ''; dependencies = $null; buildpath = $null; rolespath = $null; credentialspath = $null}
            systemconfig             = [PSCustomObject]@{ name = ''; type = 'system';                                                  dependencies_hash = ''; dependencies = $null}
        }
        
        $ConfigCombo.systemconfig.name = 'DryDeploy'
        if ($null -ne $SystemDependencies) {
            $ConfigCombo.systemconfig.dependencies = $SystemDependencies
        }
        # add methods to the object
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'Exists'      -Value $dry_core_sb_configcombo_exists
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'Read'        -Value $dry_core_sb_configcombo_read
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'Save'        -Value $dry_core_sb_configcombo_save
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'CalcDepHash' -Value $dry_core_sb_configcombo_calcdephash
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'TestDepHash' -Value $dry_core_sb_configcombo_testdephash
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'Change'      -Value $dry_core_sb_configcombo_change
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'Show'        -Value $dry_core_sb_configcombo_show
        
        if ($ConfigCombo.Exists()) {
            $ConfigCombo.Read()
        }
        else {
            $ConfigCombo.Save()
        }
        return $ConfigCombo
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}