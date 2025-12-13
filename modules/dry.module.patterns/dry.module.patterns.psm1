<#
 This module is a string-pattern-in-object-propety-values replacement module 
 for use with DryDeploy
 
 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.pattern.replace/main/LICENSE
#>

<#
    $FunctionsPath = "$PSScriptRoot\functions\*.ps1"
    $Functions     = Resolve-Path -Path $FunctionsPath -ErrorAction Stop
    foreach($function in $Functions){
        . $Function.Path
    }
#>

$ExportedFunctionsPath = "$PSScriptRoot\xfunctions\*.ps1"
$ExportedFunctions     = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $ExportedFunctions){
    . $Function.Path
}