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

function Set-DryLoggingOptions {
    [cmdletbinding()]
    param (
        [psobject]$Config,

        [string]$RootWorkingDirectory,

        [switch]$nolog
    )

    # If no logging options are defined in the $ProjectMap.logging, the values below will be used 
    $DefaultLoggingOptions = @"
    {
        "logging": {
            "log_to_file": true,
            "file": "DryDeploy.log",
            "path": "",
            "left_column_width": 30,
            "console_width_threshold": 70,
            "post_buffer": 3,
            "array_first_element_length": 45,
            "verbose": {
                "display_name": "VERBOSE:",
                "foreground_color": "yellow",
                "background_color": "Black"
            },
            "debug": {
                "display_name": "DEBUG:  ",
                "foreground_color": "yellow",
                "background_color": "DarkGrey"
            },
            "warning": {
                "display_name": "WARNING:",
                "foreground_color": "Magenta",
                "background_color": "Black"
            },
            "information": {
                "display_name": "INFO:   ",
                "foreground_color": "Magenta",
                "background_color": "Black"
            }    
        }
    }
"@
    # if the RootWorkingDirectory contains a logging options object, use that
    $UserLoggingOptionsPath = Join-Path -Path $RootWorkingDirectory -ChildPath 'LoggingOptions.json'
    if (Test-Path -Path $UserLoggingOptionsPath) {
        $LoggingOptionsObject = Get-Content -Path $UserLoggingOptionsPath -ErrorAction Stop | 
        ConvertFrom-Json -ErrorAction Stop
    }
    elseif ($Config.logging) {
        $LoggingOptionsObject = $Config.logging
    } 
    else {
        $LoggingOptionsObject = $DefaultLoggingOptions | ConvertFrom-Json -ErrorAction Stop
    }

    if ($LoggingOptionsObject.path -eq '') {
        $LoggingOptionsObject.path = Join-Path -Path $RootWorkingDirectory -ChildPath $LoggingOptionsObject.file
    }
    elseif ($null -eq $LoggingOptionsObject.path) {
        $LoggingOptionsObject | Add-Member -MemberType NoteProperty -Name 'path' -Value (Join-Path -Path $RootWorkingDirectory -ChildPath $LoggingOptionsObject.file) 
    }
    

    if ($nolog) {
        $LoggingOptionsObject.log_to_file = $false
    }
    Set-Variable -Name LoggingOptions -Value $LoggingOptionsObject -Scope GLOBAL
}