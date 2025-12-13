<#
 This module is a string-pattern-in-object-propety-values replacement module 
 for use with DryDeploy
 
 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.pattern.replace/main/LICENSE
#>

function Resolve-DryReplacementPattern{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputText,

        [Parameter(Mandatory)]
        [System.Collections.Generic.List[PSObject]]$Variables
    )
    
    foreach($Variable in $Variables){
        $Pattern = "###$($Variable.Name)###"
        if($InputText -match $Pattern){
            $Value = $Variable.Value 
            $InputText = $InputText -replace $Pattern,$Value
        }
    }
    return $InputText
}