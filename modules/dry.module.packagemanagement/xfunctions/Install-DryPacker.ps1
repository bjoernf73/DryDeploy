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

function Install-DryPacker { 
    [CmdletBinding()]
    param (
        [string]$PackerTestedVersion
    )
    
    try {
        if (-not (Test-DryExeAvailability -Exe 'packer.exe')) {
            if (Test-DryElevated) {
                & choco install packer -y
                if (Test-DryExeAvailability -Exe 'packer.exe') {
                    $PackerVersion = & packer.exe -version
                    if ($PackerVersion -ge $PackerTestedVersion) {
                        ol i @('Packer',"v$PackerVersion")
                    }
                    else {
                        ol w 'Restart shell to verify install of packer'
                    }
                }
                else {
                    ol w 'Restart shell to verify install of packer'
                }
            }
            else {
                throw "Install at least Packer v$PackerTestedVersion or newer to produce images with DryImage"
            }
        }
        else {
            $PackerVersion = & packer.exe -version
            if (-not ($PackerVersion -ge $PackerTestedVersion)) {
                if (Test-DryElevated) {
                    & choco upgrade packer -y
                    $PackerVersion = & packer.exe -version
                    if ($PackerVersion -ge $PackerTestedVersion) {
                        ol i @('Packer',"v$PackerVersion")
                    }
                    else {
                        ol w 'Restart shell to verify install of packer'
                    }
                }
                else {
                    throw "Install at least Packer v$PackerTestedVersion or newer to produce images with DryImage"
                }
            }
            else {
                ol i @('Packer',"v$PackerVersion")
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}