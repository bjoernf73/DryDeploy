<# 
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
 
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

function Get-DryUtilsRandomPath {
    [CmdLetBinding()]
    [OutputType([System.String])]
    
    param (
        [Parameter(HelpMessage="Length of the file or folder name, minus extension")]
        [Int]$Length,

        [Parameter(HelpMessage="Folder path, defaults to `$env:TEMP")]
        [String]$Path,

        [Parameter(HelpMessage="Extension of the file")]
        [String]$Extension
    )

    try {
        if (-not $Length) {
            [int]$Length = 25
        }
        if ($Extension) {
            $Extension = $Extension.TrimStart('.')
        }
        if ($Path) {
            $Path = Resolve-DryUtilsFullPath -Path $Path -OutputType 'String' -Force
        }
        else {
            $Path = Resolve-DryUtilsFullPath -Path $env:TEMP -OutputType 'String'
        }
        $RandomString = New-DryUtilsRandomHex -Length $Length
        if ($Extension) {
            $RandomString = $RandomString + '.' + $Extension
        }
        return [String](Join-Path -Path $Path -ChildPath $RandomString)
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
      $Path = $null
      $RandomString = $null
      $Extension = $null
    }
}