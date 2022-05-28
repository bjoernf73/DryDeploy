<# 
    This module contains functions to resolve, get, modify and show a DryDeploy 
    Plan.  

    Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
    
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

function Show-DryActionEnd {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [DryAction] $Action,

        [Parameter(Mandatory)]
        [DateTime] $StartTime,

        [Parameter(Mandatory)]
        [DateTime] $EndTime

    )
    try {
        [timespan]$ActionSpan = ($EndTime-$StartTime)
            ol i " " -h
            ol i " "
        if ($Action.Phase) {
            ol i "Action [$($Action.action)] - Phase [$($Action.Phase)] took $($ActionSpan.ToString("dd\:hh\:mm\:ss")) to complete"
        }
        else {
            ol i "Action [$($Action.action)] took $($ActionSpan.ToString("dd\:hh\:mm\:ss")) to complete"
        }
        
            ol i " "
            ol i "Status: $($Action.Status.ToUpper())"
            ol i " "
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}