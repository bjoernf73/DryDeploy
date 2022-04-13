<# 
 This module provides functions for bootstrapping package management, 
 registering package sources and package installations for use with 
 DryDeploy. ModuleConfigs may specify dependencies in it's root config
 that this module processes.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.packagemanagement/main/LICENSE
 
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

function Install-DryModule { 
    [CmdLetBinding()]
    
    param (
        [Parameter(Mandatory,ValueFromPipeline,HelpMessage="The module to install")]
        [PSObject]$Module
    )

    try {
        $NugetScope = 'CurrentUser'
        if ($Module.scope) {
            $NugetScope = $Module.scope
        }
        $InstallModuleParams = @{
            Name = $Module.name
            SkipPublisherCheck = $true
            Scope = $NugetScope
            ErrorAction = 'Stop'
        }

        if ($Module.allowclobber) {
            $InstallModuleParams += @{
                AllowClobber = $Module.AllowClobber
            }
        }

        if ($Module.repository) {
            $InstallModuleParams += @{
                Repository = $Module.repository
            }
        }
        
        if ($Module.minimumversion) {
            $InstallModuleParams += @{
                MinimumVersion = $Module.minimumversion
            }
        }
        elseif ($Module.requiredversion) {
            $InstallModuleParams += @{
                RequiredVersion = $Module.requiredversion
            }
        }
        elseif ($Module.maximumversion) {
            $InstallModuleParams += @{
                MaximumVersion = $Module.maximumversion
            }
        }

        $ExistingModule = Get-Module -Name $Module.name -ListAvailable -ErrorAction Ignore
        if ($ExistingModule) {
            if ($Module.minimumversion) {
                if ($ExistingModule.Version -lt $Module.minimumversion) {
                    if ($Module.scope -eq 'AllUsers') {
                        if (-not (Test-DryElevated)) {
                            Throw "Some Nuget Modules must be installed in the 'AllUsers' scope - run elevated (Run as Administrator)"
                        }
                    }
                    $UpdateModuleParams = @{
                        Name = $Module.name
                        Force = $true
                        ErrorAction = 'Stop'
                    }
                    Update-Module @UpdateModuleParams
                }
            }
            elseif ($Module.maximumversion) {
                if ($ExistingModule.Version -gt $Module.maximumversion) {
                    # don't bother with this
                    ol w "The installed module '$($module.name) (version: $($ExistingModule.version))' must be manually uninstalled. You need the lower version $($module.version) instead"
                    Throw "The installed module '$($module.name) (version: $($ExistingModule.version))' must be manually uninstalled. You need the lower version $($module.version) instead"
                }
            }
            elseif ($module.requiredversion) {
                if ($ExistingModule.Version -ne $Module.requiredversion) {
                    # don't bother with this
                    ol w "The installed module '$($module.name) (version: $($ExistingModule.version))' must be manually uninstalled. You need required version $($module.version) instead"
                    Throw "The installed module '$($module.name) (version: $($ExistingModule.version))' must be manually uninstalled. You need required version $($module.version) instead"
                }
            }
        }
        else {
            if ($Module.scope -eq 'AllUsers') {
                if (-not (Test-DryElevated)) {
                    Throw "Some Nuget Modules must be installed in the 'AllUsers' scope - run elevated (Run as Administrator)"
                }
            }
            Install-Module @InstallModuleParams 
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}