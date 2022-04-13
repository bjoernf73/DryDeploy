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


function Merge-DryPSObjects {
    [CmdletBinding()]
    param (
        $FirstObject,
         
        $SecondObject,

        [Switch]$PreferSecondObjectOnConflict,

        [Switch]$FailOnConflict
    )

    try {
        # accumulate the result
        $Private:Resultobject = New-Object -TypeName psobject
        $Private:ProcessedConflictingPropertyNames = @()

        # if both are arrays, merge
        if (($FirstObject -is [Array]) -and ($SecondObject -is [Array])) {
            $Private:ResultArray+=$FirstObject
            $Private:ResultArray+=$SecondObject
            return $Private:ResultArray 
        }
        elseif (($FirstObject -is [String]) -and ($SecondObject -is [String])) {
            # This happens when two identical property names are being merged. By default, the value from 
            # $FirstObject is returned, unless the switch $PreferSecondObjectOnConflict is passed - then 
            # the value from $SecondObject is returned. In any case, if the switch $FailOnConflict, 
            # is passed, throw an error
            if ($FailOnConflict) {
                throw "Conflict disallowed!"
            }
            else {
                if ($PreferSecondObjectOnConflict) {
                    return $SecondObject
                } 
                else {
                    return $FirstObject
                }
            }
        }
        elseif (($FirstObject -is [PSCustomObject]) -and ($SecondObject -is [PSCustomObject])) {
            # Iterate through each object property of $FirstObject
            foreach ($Property in $FirstObject | Get-Member -type NoteProperty, Property) {
                # does SecondObject have a matching property name?
                if ($null -eq $SecondObject.$($Property.Name)) {
                    # $SecondObject does not contain the current property from $FirstObject, so 
                    # the property can be added to $Private:Resultobject as it is
                    $Private:Resultobject | Add-Member -MemberType $Property.MemberType -Name $Property.Name -Value $FirstObject.($Property.Name)
                }
                else {
                    # $SecondObject contains the current property from $FirstObject, so 
                    # the two must be merged. Call Merge-PSObject
                    $Private:Resultobject | Add-Member $Property.MemberType -Name $Property.Name -Value (Merge-DryPSObjects -FirstObject ($FirstObject.$($Property.Name)) -SecondObject ($SecondObject.$($Property.Name)) -PreferSecondObjectOnConflict:$PreferSecondObjectOnConflict -FailOnConflict:$FailOnConflict)
                    $Private:ProcessedConflictingPropertyNames += $Property.Name
                }
            }

            # Members in $SecondObject that are not yet processed, has no match in 
            # $FirstObject, and may be added to the result as is
            foreach ($Property in $SecondObject | Get-Member -type NoteProperty, Property) {
                if ($Private:ProcessedConflictingPropertyNames -notcontains $Property.Name) {
                    $Private:Resultobject | Add-Member -MemberType $Property.MemberType -Name $Property.Name -Value $SecondObject.($Property.Name)
                }
                else {
                    ol d "Property '$($Property.Name)' is already processed"
                }
            }
            return $Private:Resultobject
        }
        else {
            throw "FirstObject type: $($($FirstObject.Gettype()).Name) (Basetype: $($($FirstObject.Gettype()).BaseType))"
        }

    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}