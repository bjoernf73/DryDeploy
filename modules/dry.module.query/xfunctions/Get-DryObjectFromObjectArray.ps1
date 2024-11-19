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

function Get-DryObjectFromObjectArray {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Array]$ObjectArray,

        [Parameter(Mandatory,HelpMessage="The object property name that  
        identifies the object")]
        [string]$IDProperty,

        [Parameter(Mandatory,HelpMessage="The object property value that
        identifies the object")]
        [string]$IDPropertyValue,

        [Parameter(HelpMessage="The ObjectArray may contain multiple matching
        objects, but you want the first found object")]
        [Switch]$First,

        [Parameter(HelpMessage="The ObjectArray may contain multiple matching
        objects, but you want the last found object")]
        [Switch]$Last,

        [Parameter(HelpMessage="The ObjectArray may contain multiple matching
        objects, but you want the numbered object. Objects are numbered
        1,2,3 meaning that `$Number = 1 corresponds to `$MatchObjects[0]")]
        [int]$Number,

        [Parameter(HelpMessage="By default, we assume that the ObjectArray
        contains one, and only one, unique object to match, and an exception
        will be thrown if that's not the case. Use this if multiple matches 
        is expected. This is automatically true if `$First, `$Last or 
        `$Number")]
        [Switch]$AllowMultipleMatches,

        [Parameter(HelpMessage="The default we assume that the ObjectArray
        should contain a match, and an exception will be thrown if that's 
        not the case. Use this to allow no match. `$null will be returned
        if no match is found.")]
        [Switch]$AllowNoMatch
    )
    
    try {
        if ($First -or $Last -or $Number) {
            $AllowMultipleMatches = $true
        }

        [Array]$MatchObjects = @($ObjectArray | Where-Object {
            $_."$IDProperty" -eq "$IDPropertyValue"
        })

        if (($MatchObjects.count -gt 1) -and (-not $AllowMultipleMatches)) {
            throw "The ObjectArray contained more than one match. Use '-AllowMultipleMatches' if that should be allowed"
        }
        if (($MatchObjects.count -eq 0) -and (-not $AllowNoMatch)) {
            throw "The ObjectArray contained no match. Use '-AllowNoMatch' if that should be allowed"
        }
        if ($null -eq $MatchObjects) {
            return $null
        }
        else {
            if ($First) {
                $MatchObject = $MatchObjects[0]
            }
            elseif ($Last) {
                $MatchObject = $MatchObjects[-1]
            }
            elseif ($Number) {
                $n = $Number+1
                $MatchObject = $MatchObjects[$n]
            }
            else {
                if ($MatchObjects.count -eq 1) {
                    $MatchObject = $MatchObjects[0]
                }
                else {
                    $ReturnMultiple = $true
                }
            }

            if ($ReturnMultiple) {
                return $MatchObjects
            }
            else {
                return $MatchObject
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $MatchObjects = $null
    }
}