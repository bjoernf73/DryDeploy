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

function Install-DryOscdImg {
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage="To avoid applocker restriction, specify an applocker-allowed path to execute the installer in")]
        [String]$TempPath
    )

    try {
        if (-not (Test-DryExeAvailability -Exe 'oscdimg.exe')) {
            if (-not (Test-DryElevated)) {
                throw "The imaging tool OSCDIMG should be installed - execute me elevated to install it"
            }
            else {
                if ($TempPath) {
                    $AdkSetupFile = Join-Path -Path $TempPath -ChildPath 'adksetup.exe'
                    $AdkSetupLog  = Join-Path -Path $TempPath -ChildPath 'adksetup.log'
                }
                else {
                    $AdkSetupFile = Join-Path -Path $env:Temp -ChildPath 'adksetup.exe'
                    $AdkSetupLog  = Join-Path -Path $env:Temp -ChildPath 'adksetup.log'
                }
                $Url               = 'https://go.microsoft.com/fwlink/?linkid=2120254'
                $SourceOSCdImgPath = "$env:SystemDrive\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
                $TargetOSCdImgPath = Join-Path -Path $env:windir -ChildPath 'oscdimg.exe'
        
                if (-not (Test-Path -Path $TargetOSCdImgPath)) {
                    if (-not (Test-Path -Path $SourceOSCdImgPath)) {
                        if (-not (Test-Path -Path $AdkSetupFile)) {
                            Invoke-WebRequest -Uri $Url -OutFile $AdkSetupFile -ErrorAction Stop
                        }
                        & $AdkSetupFile /quiet /norestart /log $AdkSetupLog /features OptionId.DeploymentTools
                    }
                    do {
                        Start-Sleep -Seconds 3
                        if (Test-Path -Path $SourceOSCdImgPath) {
                            Start-Sleep -Seconds 1
                            Copy-Item -Path $SourceOSCdImgPath -Destination $TargetOSCdImgPath -Force
                        }
                    }
                    while (-not (Test-Path -path $TargetOSCdImgPath))
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}