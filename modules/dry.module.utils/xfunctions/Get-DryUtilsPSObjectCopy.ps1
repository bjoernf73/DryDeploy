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

function Get-DryUtilsPSObjectCopy{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,HelpMessage="The Object to make an unreferenced copy from")]
        [PSObject]$Object,

        [Parameter(HelpMessage="Properties to add or change")]
        [hashtable]$Properties
    )
  
    [PSObject]$Copy = $Object | ConvertTo-Json -Depth 100 -Compress -ErrorAction Stop | 
    ConvertFrom-Json -ErrorAction Stop
    
    # Will only work on properties at root though
    if($Properties){
        foreach($Key in $Properties.Keys){
            if($null -eq $Object."$Key"){
                Write-Host "The Property '$Key' does not exist!"
                $Object | Add-Member -MemberType NoteProperty -Name $Key -Value $Properties["$Key"]
            }
            else{
                Write-Warning "The Property '$Key' existed on the object already" -WarningAction Continue
                $Object."$Key" = $Properties["$Key"]
            }
        }
    }
    return $Copy
}