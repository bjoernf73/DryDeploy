<#  
    This is an AD Config module for use with DryDeploy, or by itself.
    Copyright (C) 2021  Bjørn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.ad/main/LICENSE

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
function Get-DryADJson {
    [CmdletBinding()]
    param (
        [ValidateScript({ (Test-Path $_ -PathType 'leaf') -and (($_ -match ".json$") -or ($_ -match ".jsonc$")) })]
        [Parameter(Mandatory, ParameterSetName = 'stringpath')]
        [string]$Path,

        [ValidateScript({ ($_.exists -and (($_.name -match ".json$") -or ($_.name -match ".jsonc$"))) })]
        [Parameter(Mandatory, ParameterSetName = 'fileinfo')]
        [System.IO.FileInfo]$File
    )
    try {
        if ($Path) {
            [System.IO.FileInfo]$Item = Get-Item -Path $Path -ErrorAction Stop
        }
        else {
            [System.IO.FileInfo]$Item = $File
        }
        
        # Get all lines that does not start with comment, i.e "//"
        [Array]$ContentArray = Get-Content -Path $Item -ErrorAction Stop | Where-Object { 
            $_.Trim() -notmatch "^//" 
        }

        [string]$ContentString = $ContentArray | Out-String -ErrorAction 'Stop'

        # Convert to PSObject and return
        ConvertFrom-Json -InputObject $ContentString -ErrorAction 'Stop'
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
