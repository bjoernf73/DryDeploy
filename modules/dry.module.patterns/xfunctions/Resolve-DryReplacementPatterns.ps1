<#
 This module is a string-pattern-in-object-propety-values replacement module 
 for use with DryDeploy
 
 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.pattern.replace/main/LICENSE
 
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

function Resolve-DryReplacementPatterns {
    [CmdletBinding()]
    param (
        [Parameter(ParametersetName="InputObject",Position=0,Mandatory)]
        [PSCustomObject]$InputObject,

        [Parameter(ParametersetName="InputText",Position=0,Mandatory)]
        [AllowEmptyString()]
        [string]$InputText,

        [Parameter(ParametersetName="InputObject",Position=1,Mandatory)]
        [Parameter(ParametersetName="InputText",Position=1,Mandatory)]
        [System.Collections.Generic.List[PSObject]]$Variables
    )

    try {
        if (($InputObject -is [Array]) -and $InputObject.count -eq 0) {
            return
        } 
        elseif ($InputObject) {
            if ($InputObject -is [Array]) {
                # make a copy of the object, so changes don't infect the original
                [Array]$CopyObject = $InputObject.PSObject.Copy()
                $ResultArray = @()
                foreach ($arrItem in $CopyObject) {
                    $ResultArray+= Resolve-DryReplacementPatterns -InputObject $arrItem -Variables $Variables
                }
                $ResultArray
            }
            else {
                # make a copy of the object, so changes don't infect the original
                $CopyObject = $InputObject.PSObject.Copy()
                $CopyObject.PSObject.Properties | Foreach-Object {
                    $PropertyName  = $_.Name
                    $PropertyValue = $_.Value
                    if (($PropertyName -match "common_variables$") -or ($PropertyName -match "resource_variables$")) {
                        # the common_variables and resource_variables define the strings to replace, so 
                        # avoid replacing them, return the original object
                    }
                    elseif ($PropertyValue -is [string]) {
                        # if name is a string, we can replace
                        $PropertyValue = Resolve-DryReplacementPattern -InputText $PropertyValue -Variables $Variables     
                    }
                    elseif ($PropertyValue -is [Array]) {
                        # nested call for each element in array
                        $PropertyValue = @($PropertyValue | Foreach-Object { 
                            if ($_ -is [string]) {
                                Resolve-DryReplacementPatterns -InputText $_ -Variables $Variables
                            } 
                            else {
                                Resolve-DryReplacementPatterns -InputObject $_ -Variables $Variables
                            }
                        })
                    }
                    elseif ($PropertyValue -is [PSObject]) {
                        # nested call
                        $PropertyValue = Resolve-DryReplacementPatterns -InputObject $PropertyValue -Variables $Variables
                    } 
                    $CopyObject."$PropertyName" = $PropertyValue
                }
                return $CopyObject
            }
        } 
        else { 
            Resolve-DryReplacementPattern -InputText $InputText -Variables $Variables
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}