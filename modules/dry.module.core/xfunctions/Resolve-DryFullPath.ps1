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
function Resolve-DryFullPath {
    [cmdletbinding()]
    param (
        [string] 
        $Path,

        [System.IO.DirectoryInfo] 
        $RootPath
    )

    try {
        # if no RootPath is specified, use the current working directory
        if (-not ($RootPath)) {
            [System.IO.DirectoryInfo]$RootPath = ($PWD).Path
        }

        # determine the slash - backslash on windows, slash on Linux
        $slash = '\'
        if ($PSVersionTable.Platform -eq 'Unix') {
            $slash = '/'
        }
        
        # Path cannot be a system.io-object, because it does not necessarily exist
        if ($Path -match "^\.") {
            # Path relative to the current directory
            $FullPath = [IO.Path]::GetFullPath("$RootPath$($slash)$Path")
        }
        else {
            # Full path
            $FullPath = [IO.Path]::GetFullPath("$Path")
        }
        return $FullPath
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}