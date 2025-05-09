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

function Set-DryConfigData {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('json','yml')]
        [string]$Type,

        [Parameter(Mandatory)]
        [System.Text.Encoding]$Encoding,

        [Parameter(Mandatory,HelpMessage="Object to write to file")]
        [PSCustomObject]$Configuration
    )
    try {
        $FullPath = Resolve-DryUtilsFullPath -Path $Path
        $Folder = Split-Path -Path $FullPath -ErrorAction Stop -Parent -ErrorAction Stop
        if (-not(Test-Path -Path $FolderPath -ErrorAction Ignore)) {
            New-Item -Path $Folder -ItemType Directory -Force -Confirm:$false -ErrorAction Stop
        }
        switch ($Type) {
            'json' {
                $Configuration = ConvertTo-Json -DryFromJson -Path $File.FullName -Force -Confirm:$false -ErrorAction Stop
            }
            'yml' {
                try {
                    $Configuration | ConvertTo-Yaml -Path $File.FullName -ErrorAction Stop 
                }
                catch [System.Management.Automation.CommandNotFoundException] {
                    ol w 'Missing Powershell Module','powershell-yaml'
                    throw $_
                }
                catch {
                    throw $_
                }
                
            }
        }
    
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}