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

function Register-DryPSRepository { 
    [CmdLetBinding()]
    param (
        [PSObject]$Repository
    )

    try {
        try {
            $RegisteredRepository = Get-PSrepository -name $Repository.Name 
            if ($RegisteredRepository.InstallationPolicy -ne $Repository.InstallationPolicy) {
                Set-PSRepository -Name $Repository.Name -InstallationPolicy $Repository.InstallationPolicy -ErrorAction Stop
            }
        }
        catch {
            if ($_.CategoryInfo.Category -eq 'ObjectNotFound') {
                $RepositoryPropertiesHash = @{}
                $Repository.PSObject.Properties | foreach-Object {
                    $RepositoryPropertiesHash.Add($_.Name,$Repository.($_.Name))   
                }
                $RepositoryPropertiesHash.Add('ErrorAction','Stop')
                Register-PSRepository @RepositoryPropertiesHash 
            }
            else {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}