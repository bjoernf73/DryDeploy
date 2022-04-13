<#  
    This is an AD Config module for use with DryDeploy, or by itself.
    Copyright (C) 2021  Bjørn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.ad/main/LICENSE

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
Function Merge-DryADPSObjects {
    [CmdLetBinding()]
    Param (
        $FirstObject,
         
        $SecondObject,

        [Switch]$PreferSecondObjectOnConflict,

        [Switch]$FailOnConflict
    )
    try {
        # This will accumulate the result
        $Private:Resultobject = New-Object -TypeName psobject
        $Private:ProcessedConflictingPropertyNames = @()

        # is both are arrays, merge
        If (($FirstObject -is [Array]) -and ($SecondObject -is [Array])) {
            $Private:ResultArray += $FirstObject
            $Private:ResultArray += $SecondObject
            Return $Private:ResultArray 
        }
        ElseIf ( ($FirstObject -is [String]) -and $SecondObject -is [String] ) {
            # This happens when properties are identical in above iterations. By default, the property from 
            # $FirstObject is returned, unless the switch $PreferSecondObjectOnConflict is passed - then 
            # the property from $SecondObject is returned. In any case, if the switch $FailOnConflict, 
            # is passed, we throw an error
            If ($FailOnConflict) {
                Throw "There was conflict (identical properties) and you passed -FailonConflict"
            }
            Else {
                If ($PreferSecondObjectOnConflict) {
                    Return $SecondObject
                } 
                Else {
                    Return $FirstObject
                }
            }
        }
        ElseIf ( ($FirstObject -is [PSCustomObject]) -and $SecondObject -is [PSCustomObject] ) {
            # Iterate through each object property of $FirstObject
            ForEach ($Property in $FirstObject | Get-Member -Type NoteProperty, Property) {
                # does SecondObject have a matching node?
                If ($null -eq $SecondObject.$($Property.Name)) {
                    # $SecondObject does not contain the current property from $FirstObject, so 
                    # the property can be added to $Private:Resultobject as it is
                    $Private:Resultobject | Add-Member -MemberType $Property.MemberType -Name $Property.Name -Value $FirstObject.($Property.Name)
                }
                Else {
                    # $SecondObject contains the current property from $FirstObject, so 
                    # the two must be merged. Call Merge-DryADPSObject
                    $Private:Resultobject | Add-Member $Property.MemberType -Name $Property.Name -Value ( Merge-DryADPSObjects -FirstObject ($FirstObject.$($Property.Name)) -SecondObject ($SecondObject.$($Property.Name)) -PreferSecondObjectOnConflict:$PreferSecondObjectOnConflict -FailOnConflict:$FailOnConflict)
                    $Private:ProcessedConflictingPropertyNames += $Property.Name
                }
            }

            # Members in $SecondObject that are not yet processed, has no 
            # match in $FirstObject, and may be added to the result as is
            ForEach ($Property in $SecondObject | Get-Member -type NoteProperty, Property) {
                If ($Private:ProcessedConflictingPropertyNames -notcontains $Property.Name) {
                    ol d "Trying to add property '$($Property.Name)', type '$($Property.MemberType)', Value '$($SecondObject.($Property.Name))' "

                    $Private:Resultobject | Add-Member -MemberType $Property.MemberType -Name $Property.Name -Value $SecondObject.($Property.Name)
                }
                Else {
                    ol d "Property '$($Property.Name)' is already processed"
                }
            }
            Return $Private:Resultobject
        }
        Else {
            ol e "FirstObject type: $($($FirstObject.Gettype()).Name) (Basetype: $($($FirstObject.Gettype()).BaseType))"
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    Catch {
        $PSCmdLet.ThrowTerminatingError($_)
    }
}
