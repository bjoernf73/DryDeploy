<# 
 This module provides generic functions for use with DryDeploy.

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


function Get-DryCommentedJson {
    [CmdletBinding()]
    param (
        [ValidateScript({(Test-Path $_ -PathType 'leaf') -and (($_ -match ".jsonc$") -or ($_ -match ".json$"))})]
        [Parameter(Mandatory,ParameterSetName='stringpath')]
        [String]$Path,

        [ValidateScript({($_.exists)})]
        [Parameter(Mandatory,ParameterSetName='fileinfo')]
        [System.IO.FileInfo]$File
    )
    try {
        # Get Path of file 
        if ($File) {
            $Path = $File.FullName
        }
       
        # Get all lines that does not start with comment, i.e "//"
        [Array]$ContentArray = Get-Content $Path -ErrorAction Stop | 
        Where-Object { 
            $_.Trim() -notmatch "^//" 
        }

        # Remove any comment at the end of line
        for ($Line = 0; $Line -lt $ContentArray.Count; $Line++) {
            if ($ContentArray[$Line] -match "//") {
                $ContentArray[$Line] = $ContentArray[$Line].Substring(0, $ContentArray[$Line].IndexOf('//'))
            }
        }

        [String]$ContentString = $ContentArray | 
        Out-String -ErrorAction 'Stop'
        ConvertFrom-Json -InputObject $ContentString -ErrorAction 'Stop'
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}