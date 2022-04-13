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

function Get-DryDependenciesHash {
    [CmdLetBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory)]
        [PSObject]$Dependencies
    )
    try {
        # accumulate a string that represents the host and all packages
        $HostName = ([System.NET.DNS]::GetHostByName('')).HostName
        $DependenciesString = $HostName

        foreach ($Dependency in $Dependencies.nuget.modules) {
            $DependenciesString += $Dependency.name
            if ($Dependency.minimumversion) {
                $DependenciesString += $Dependency.minimumversion
            }
            if ($Dependency.maximumversion) {
                $DependenciesString += $Dependency.maximumversion
            }
            if ($Dependency.requiredversion) {
                $DependenciesString += $Dependency.requiredversion
            }
        }

        foreach ($Dependency in $Dependencies.choco.packages) {
            $DependenciesString += $Dependency.name
            if ($Dependency.version) {
                $DependenciesString += $Dependency.version
            }
        }

        foreach ($Dependency in $Dependencies.git.projects) {
            $DependenciesString += $Dependency.url
            $DependenciesString += $Dependency.branch
        }

        # calculate a sha256 hash of the string
        $DotNetHasher     = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
        $ByteArray        = $DotNetHasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($DependenciesString))
        $DependenciesHash = [System.BitConverter]::ToString($ByteArray)
        $DependenciesHash
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        ol d @('Dependency string',"$DependenciesString")
        ol d @('Dependency hash',"$DependenciesHash")
        $DependenciesString = $null
        $DependenciesHash   = $null
        $DotNetHasher       = $null
        $ByteArray          = $null
    }
}