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

#! Should rather be configured to allow winrm 
#! to the specific resources a run configures
function Set-DryWinrm { 
    [CmdLetBinding()]
    param ()

    try {
       
        $ChangedSomething = $false
        $Service = Get-Service -Name 'WinRM' -ErrorAction Stop
        if ($Service.StartType -ne 'Automatic') {
            if (Test-DryElevated) {
                $Service | Set-Service -StartupType 'Automatic'
                $ChangedSomething = $true
            }
            else {
                throw 'Run elevated to -init'
            }
        }
        
        if ($Service.Status -ne 'Running') {
            if (Test-DryElevated) {
                $Service | Start-Service -ErrorAction Stop
                $ChangedSomething = $true
            }
            else {
                throw 'Run elevated to -init'
            }
        }
        $TrustedHostsPath = 'Wsman:\localhost\Client\TrustedHosts'
        $TrustedHosts = Get-Item -Path $TrustedHostsPath -ErrorAction Stop
        if ($TrustedHosts.Value -ne '*') {
            if (Test-DryElevated) {
                Set-Item -Path $TrustedHostsPath -Value * -Force
                $ChangedSomething = $true
            }
            else {
                throw 'Run elevated to -init'
            }
        }
        
        if ($ChangedSomething) {
            $Service | Restart-Service -Force -ErrorAction Stop
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}