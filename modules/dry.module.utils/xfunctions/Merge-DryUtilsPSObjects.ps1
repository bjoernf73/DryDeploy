<#
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function Merge-DryUtilsPSObjects{
    [CmdletBinding()]
    param(
        $FirstObject,

        $SecondObject,

        [Switch]$PreferSecondObjectOnConflict,

        [Switch]$FailOnConflict
    )

    try{
        # accumulate the result
        $Private:Resultobject = New-Object -TypeName psobject
        $Private:ProcessedConflictingPropertyNames = @()

        # if both are arrays, merge
        if(($FirstObject -is [array]) -and ($SecondObject -is [array])){
            $Private:ResultArray+=$FirstObject
            $Private:ResultArray+=$SecondObject
            return $Private:ResultArray
        }
        elseif(($FirstObject -is [string]) -and ($SecondObject -is [string])){
            # This happens when two identical property names are being merged. By default, the value from
            # $FirstObject is returned, unless the switch $PreferSecondObjectOnConflict is passed - then
            # the value from $SecondObject is returned. In any case, if the switch $FailOnConflict,
            # is passed, throw an error
            if($FailOnConflict){
                throw "Conflict disallowed!"
            }
            else{
                if($PreferSecondObjectOnConflict){
                    return $SecondObject
                }
                else{
                    return $FirstObject
                }
            }
        }
        elseif(($FirstObject -is [PSCustomObject]) -and ($SecondObject -is [PSCustomObject])){
            # Iterate through each object property of $FirstObject
            foreach($Property in $FirstObject | Get-Member -type NoteProperty, Property){
                # does SecondObject have a matching property name?
                if($null -eq $SecondObject.$($Property.Name)){
                    # $SecondObject does not contain the current property from $FirstObject, so
                    # the property can be added to $Private:Resultobject as it is
                    $Private:Resultobject | Add-Member -MemberType $Property.MemberType -Name $Property.Name -Value $FirstObject.($Property.Name)
                }
                else{
                    # $SecondObject contains the current property from $FirstObject, so
                    # the two must be merged. Call Merge-PSObject
                    $Private:Resultobject | Add-Member $Property.MemberType -Name $Property.Name -Value (Merge-DryUtilsPSObjects -FirstObject ($FirstObject.$($Property.Name)) -SecondObject ($SecondObject.$($Property.Name)) -PreferSecondObjectOnConflict:$PreferSecondObjectOnConflict -FailOnConflict:$FailOnConflict)
                    $Private:ProcessedConflictingPropertyNames += $Property.Name
                }
            }

            # Members in $SecondObject that are not yet processed, has no match in
            # $FirstObject, and may be added to the result as is
            foreach($Property in $SecondObject | Get-Member -type NoteProperty, Property){
                if($Private:ProcessedConflictingPropertyNames -notcontains $Property.Name){
                    $Private:Resultobject | Add-Member -MemberType $Property.MemberType -Name $Property.Name -Value $SecondObject.($Property.Name)
                }
                else{
                    ol d "Property '$($Property.Name)' is already processed"
                }
            }
            return $Private:Resultobject
        }
        else{
            throw "FirstObject type: $($($FirstObject.Gettype()).Name) (Basetype: $($($FirstObject.Gettype()).BaseType))"
        }

    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}