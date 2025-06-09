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


function Wait-DryUtilsRestart{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter()]
        [int]$MinimumTimeOuts = 3

    )

    throw "This function does not do anything until it is written"
     
    [bool]$RebootConfirmed = $false
    $TestResults = @()
    for ($i=0; $i -lt $MinimumTimeOuts; $i++){
        $TestResults += $false
    }

    do{
        if( Test-Connection -ComputerName $ComputerName -Protocol TCP -Count 1 ){
            # Add result to $TestResults
        }
    }
    while (-not $RebootConfirmed)
}