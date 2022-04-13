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

function Install-DryChocoPackage {
    [CmdLetBinding()]
    
    param (
        [Parameter(HelpMessage="Name of the Package to install")]
        [String]$Name,
        [String]$MinimumVersion,
        [String]$RequiredVersion
    )

    try {
        $InstallParams = @{
            Name = "$Name"
        }
        if ($MinimumVersion) {
            $InstallParams = @{
                Version = "$MinimumVersion"
            }
        }
        if ($RequiredVersion) {
            $InstallParams = @{
                Version = "$RequiredVersion"
            }
        }

        $Installed = Get-ChocoPackage -Name $Name -LocalOnly
        if ($Null -eq $Installed) {
            Install-ChocoPackage @InstallParams
        }
        else {
            if ($MinimumVersion) {
                if ($MinimumVersion -gt $Installed.Version) {
                    # & "$($env:Programdata)\Chocolatey\bin\choco.exe" upgrade "$($_.Name)" -y
                    Install-ChocoPackage @InstallParams
                }
            }
            elseif ($RequiredVersion) {
                if ($RequiredVersion -ne $Installed.Version) {
                    $InstallParams += {
                        Force = $true
                    }
                    Install-ChocoPackage @InstallParams
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $Installed = $Null
        $InstallParams = $Null
    }
}