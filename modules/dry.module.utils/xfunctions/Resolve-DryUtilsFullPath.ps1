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

function Resolve-DryUtilsFullPath{
    [CmdLetBinding()]
    [OutputType([System.String],[System.Management.Automation.PathInfo],[System.IO.FileInfo],[System.IO.DirectoryInfo])]
    
    param(
        [Parameter(Mandatory,HelpMessage="Releative or absolute path of any kind")]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(HelpMessage="The type to return. Only existing objects may return")]
        [ValidateSet('String','PathInfo','FileInfo','DirectoryInfo',$null)]
        [string]$OutputType,

        [Parameter(HelpMessage="Ensures the path is resolved and returned as a string even though the item doesn't exist")]
        [Switch]$Force
    )
    try{
        if(-not $OutputType){
            $OutputType = 'String'
        }
        try{
            [System.Management.Automation.PathInfo]$PathInfo = Resolve-Path -Path $Path -ErrorAction Stop
            try{
                switch($OutputType){
                    'PathInfo'{
                        [System.Management.Automation.PathInfo]$FullPath = $PathInfo
                    }
                    'FileInfo'{
                        [System.IO.FileInfo]$FullPath = Get-Item -Path $PathInfo -ErrorAction Stop
                    }
                    'DirectoryInfo'{
                        [System.IO.DirectoryInfo]$FullPath = Get-Item -Path $PathInfo -ErrorAction  Stop
                    }
                    default{
                        [System.String]$FullPath = $PathInfo.Path
                    }
                }
            }
            catch{
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        catch [System.Management.Automation.ItemNotFoundException]{
            if($Force){
                [string]$FullPath = $_.TargetObject
                if($OutputType -ne 'String'){
                    throw "The path '$FullPath' does not exist, and cannot be converted to '$OutputType'"
                }
            }
            else{
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        catch{
            $PSCmdlet.ThrowTerminatingError($_)
        }
        return $FullPath
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
        $PathInfo = $null
        $FullPath = $null
    }
}