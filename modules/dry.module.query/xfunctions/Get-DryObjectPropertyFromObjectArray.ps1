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

function Get-DryObjectPropertyFromObjectArray {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Array]$ObjectArray,

        [Parameter(Mandatory,HelpMessage="The object property name that  
        identifies the object from which `$Property will be returned")]
        [String]$IDProperty,

        [Parameter(Mandatory,HelpMessage="The object property value that
        identifies the object from which `$Property will be returned")]
        [String]$IDPropertyValue,

        [Parameter(Mandatory,HelpMessage="The property name who's value
        will be returned")]
        [String]$Property,

        [Parameter(HelpMessage="The ObjectArray may contain multiple matching
        objects, but you want the first found object's values")]
        [Switch]$First,

        [Parameter(HelpMessage="The ObjectArray may contain multiple matching
        objects, but you want the last found object's values")]
        [Switch]$Last,

        [Parameter(HelpMessage="The ObjectArray may contain multiple matching
        objects, but you want the value from the numbered item. Items are numbered
        1,2,3 meaning that `$Number = 1 corresponds to `$MatchObjects[0]")]
        [Int]$Number,

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
        [Switch]$AllowNoMatch,

        [Parameter(HelpMessage="The default, assumes that the property 
        `$Property should exist on the matching object, and an exception 
        will be thrown if that's not the case. Use to allow this, and 
        just return `$null")]
        [Switch]$AllowNoProperty
    )
    
    try {
        ol 5 @('IDProperty',$IDProperty)
        ol 5 @('IDPropertyValue',$IDPropertyValue)
        ol 5 @('Property',$Property)
        ol 5 @('First',$First)
        ol 5 @('Last',$Last)
        ol 5 @('Number',$Number)
        ol 5 @('AllowMultipleMatches',$AllowMultipleMatches)
        ol 5 @('AllowNoMatch',$AllowNoMatch)
        ol 5 @('AllowNoProperty',$AllowNoProperty)


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
            if ($First)  {
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
                $ValuesToreturn = @()
                $MatchObjects.foreach({
                    if ($_.PSObject.Properties.Name -contains "$Property") {
                        $ValuesToreturn += $_."$Property"
                    }
                    else {
                        if (-not $AllowNoProperty) {
                            throw "One or more matching object does not contain the property $Property"
                        }
                    }
                })
                return $ValuesToReturn
            }
            else {
                if ($MatchObject.PSObject.Properties.Name -contains "$Property") {
                    return $MatchObject."$Property"
                }
                else {
                    if ($AllowNoProperty) {
                        return $null
                    }
                    else {
                        throw "The matching object does not contain the property $Property"
                    }
                }
            }
        }
    }
    catch {
        ol 3 "The input object array is returned below:"
        $ObjectArray
        
        ol 3 "And these are the input params:"
        ol 3 @('IDProperty',$IDProperty)
        ol 3 @('IDPropertyValue',$IDPropertyValue)
        ol 3 @('Property',$Property)
        ol 3 @('First',$First)
        ol 3 @('Last',$Last)
        ol 3 @('Number',$Number)
        ol 3 @('AllowMultipleMatches',$AllowMultipleMatches)
        ol 3 @('AllowNoMatch',$AllowNoMatch)
        ol 3 @('AllowNoProperty',$AllowNoProperty)
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $MatchObjects = $null
    }
}