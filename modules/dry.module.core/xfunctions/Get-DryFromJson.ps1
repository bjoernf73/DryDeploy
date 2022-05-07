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

function Get-DryFromJson {
    [CmdletBinding()]
    param (
        [ValidateScript({(Test-Path $_ -PathType 'leaf') -and (($_ -match ".jsonc$") -or ($_ -match ".json$"))})]
        [Parameter(Mandatory,Position=0,ParameterSetName='StringPath')]
        [System.String]
        $Path,

        [ValidateScript({($_.exists)})]
        [Parameter(Mandatory,Position=0,ParameterSetName='FileInfoPath')]
        [System.IO.FileInfo]
        $File,

        [Parameter(Mandatory,Position=0,ParameterSetName='MaybeStringPath',
        HelpMessage="While the existence of the file that `$Path or `$File refers to is verified by 
        ValidateScripts, `$MaybePath is not. As such, you may use MaybePath if you're getting an
        optional file. If the file does not exist, the function will accept that and return `$null, 
        without throwing an exception")]
        [System.String]
        $MaybePath
    )
    try {
        Switch ($PSCmdlet.ParameterSetName) {
            'StringPath' {
                ol d 'Trying to get file from [string]',$Path
                [String]$StrPath = $Path  
                [System.IO.FileInfo]$File = Get-ChildItem -Path $Path -ErrorAction Stop
                [PSCustomObject]((($File | Get-Content -Raw -ErrorAction Stop) -replace '("(\\.|[^\\"])*")|/\*[\S\s]*?\*/|//.*', '$1') | 
                ConvertFrom-Json -ErrorAction Stop)
            }
            'FileInfoPath' {
                ol d 'Trying to get file from [fileinfo]',$File.FullName
                [String]$StrPath = $File.FullName
                # this seems counter intuitive, but the system.io.fileinfo object may just be a string cast to [system.io.fileinfo]
                [System.IO.FileInfo]$File = Get-ChildItem -Path $File -ErrorAction Stop
                [PSCustomObject]((($File | Get-Content -Raw -ErrorAction Stop) -replace '("(\\.|[^\\"])*")|/\*[\S\s]*?\*/|//.*', '$1') | 
                ConvertFrom-Json -ErrorAction Stop)
            }
            'MaybeStringPath' {
                try {
                    ol d 'Trying to get file from [string]',$MaybePath
                    [System.IO.FileInfo]$File = Get-ChildItem -Path $MaybePath -ErrorAction Stop
                    [PSCustomObject]((($File | Get-Content -Raw -ErrorAction Stop) -replace '("(\\.|[^\\"])*")|/\*[\S\s]*?\*/|//.*', '$1') | 
                    ConvertFrom-Json -ErrorAction Stop)
                }
                catch [System.Management.Automation.ItemNotFoundException] {
                    # The file doesn't exist - return $null
                    return $null
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                } 
            }
        }        
    }
    catch {
        switch ($PSCmdlet.ParameterSetName) {
            'StringPath' {
                ol d 'Failed getting',$Path
            }
            'FileInfoPath' {
                ol d 'Failed getting',$File
            }
            'MaybeStringPath' {
                ol d 'Failed getting',$MaybePath
            }
        }
        $PSCmdlet.ThrowTerminatingError($_)
    }
}