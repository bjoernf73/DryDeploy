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

function Copy-DryActionConfigurations {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]$ConfigSourcePath,

        [Parameter(Mandatory)]
        [String]$ConfigTargetPath,

        [Parameter()]
        [String]$ConfigOSSourcePath
    )
    
    try {
        # Make sure TargetFolderPath is empty
        if (Test-Path -Path $ConfigTargetPath -ErrorAction Ignore) {
            ol w "The Target temporary directory exists - removing contents"
            Remove-Item -Path "$ConfigTargetPath\*" -Recurse -Force -Confirm:$False
            Start-Sleep -Seconds 1
        }
        ol i "Copy target","$ConfigTargetPath"

        if ($ConfigSourcePath -ne '') {
            ol i "Role source","$ConfigSourcePath"
            # Copy all Role configuration files to $ConfigTargetPath
            ol v "& robocopy.exe `"$ConfigSourcePath`" `"$ConfigTargetPath`" /E"
            & robocopy.exe "$ConfigSourcePath" "$ConfigTargetPath" /E  *>&1 | 
            Tee-Object -Variable RoboOutput | 
            Out-Null

            if ($LASTEXITCODE -gt 7) {
                ol w "Error occurred copying files - robocopy exit code","$LASTEXITCODE"
                foreach ($Line in $RoboOutput) {
                    ol w "$Line"
                }
                throw "Error occurred copying files. Exit code: $LASTEXITCODE"
            }
            else {
                $LASTEXITCODE = 0
                $GLOBAL:LASTEXITCODE = 0
                foreach ($Line in $RoboOutput) {
                    ol v "$Line"
                }
            }
            Remove-Variable -Name RoboOutput -ErrorAction Ignore
        }
        else {
            ol i "Role source","(none)"
        }

        if ($ConfigOSSourcePath) {
            ol i "Copy including OS configs from source","$ConfigOSSourcePath"
            ol v "& robocopy.exe `"$ConfigOSSourcePath`" `"$ConfigTargetPath`" /E"
            & robocopy.exe "$ConfigOSSourcePath" "$ConfigTargetPath" /E  *>&1 | 
            Tee-Object -Variable RoboOutput | 
            Out-Null

            if ($LASTEXITCODE -gt 7) {
                ol w "Error occurred copying files. Exit code","$LASTEXITCODE"
                foreach ($Line in $RoboOutput) {
                    ol w "$Line"
                }
                throw "Error occurred copying files. Exit code: $LASTEXITCODE"
            }
            else {
                foreach ($Line in $RoboOutput) {
                    ol v "$Line"
                }
            }
            Remove-Variable -Name RoboOutput -ErrorAction Ignore
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}