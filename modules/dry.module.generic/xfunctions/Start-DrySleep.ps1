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


function Start-DrySleep {
    [CmdletBinding()]
    param (
        [Int]$Seconds,

        [String]$Message = "Sleeping..."
    )
    $TargetTime = (Get-Date).AddSeconds($Seconds)
    while($TargetTime -gt (Get-Date)) {
        $SecondsLeft = $TargetTime.Subtract((Get-Date)).TotalSeconds
        $Percent = ($Seconds - $SecondsLeft) / $Seconds * 100
        Write-Progress -Activity "Sleeping" -Status "$Message" -SecondsRemaining $SecondsLeft -PercentComplete $Percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining 0 -Completed
}