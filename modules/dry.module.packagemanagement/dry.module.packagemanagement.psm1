<# 
 This module provides functions for bootstrapping package management, 
 registering package sources and package installations for use with 
 DryDeploy. ModuleConfigs may specify dependencies in it's root config
 that this module processes. 

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.packagemanagement/main/LICENSE
#>

$FunctionsPath = "$PSScriptRoot\functions\*.ps1"
$Functions     = Resolve-Path -Path $FunctionsPath -ErrorAction Stop
foreach($function in $Functions){
    . $Function.Path
}

$ExportedFunctionsPath = "$PSScriptRoot\xfunctions\*.ps1"
$ExportedFunctions     = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $ExportedFunctions){
    . $Function.Path
}