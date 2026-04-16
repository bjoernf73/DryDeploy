<#
 This module provides query functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.query/main/LICENSE
#>

<#
.SYNOPSIS
Gets a named variable value from $Variables

.DESCRIPTION
Variables is a (System.Collections.Generic.)List of PSObjects
with a name and value property. You pass in $Variables and the
name, I return the value

.PARAMETER Variables
The [System.Collections.Generic.List] containing [PSObject]s
with a name and a value property

.EXAMPLE
Get-DryVariableValue -Variables $Variables -Name DomainNB
Returns the value property of the PSObject in $Variables
that has a .name property of 'DomainNB'
#>
function Get-DryVariableValue{
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[PSObject]]$Variables,

        [Parameter(HelpMessage="The variable name to get from `$Variables")]
        [string]$Name
    )

    try{
        Remove-Variable -Name Variable -ErrorAction Ignore
        $Variable = $Variables | Where-Object{
            $_.Name -eq $Name
        }
        if($null -eq $Variable){
            ol w "Variables does not contain a variable named '$Name'"
            throw "Variables does not contain a variable named '$Name'"
        }
        elseif($Variable -is [array]){
            ol w "Variables contains multiple variables named '$Name'"
            throw "Variables contains multiple variables named '$Name'"
        }
        else{
            return $Variable.Value
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}