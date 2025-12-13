<#
 This module handles credentials for DryDeploy

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.credential/main/LICENSE
#>

$ClassesPath = "$PSScriptRoot\classes\*.ps1"
$Classes     = Resolve-Path -Path $ClassesPath -ErrorAction Stop
foreach($Class in $Classes){
    . $Class.Path
}

$ExportedFunctionsPath = "$PSScriptRoot\xfunctions\*.ps1"
$ExportedFunctions     = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $ExportedFunctions){
    . $Function.Path
}