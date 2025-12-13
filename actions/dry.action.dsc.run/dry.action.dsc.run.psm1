# This module is an action module for use with DryDeploy. It runs a DSC 
# Config on a target
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.dsc.run/main/LICENSE
# 


# Dot source all functionscripts - the manifest limits exported functions
$FunctionsPath = "$PSScriptRoot\Functions\*.ps1"
$Functions     = Resolve-Path -Path $FunctionsPath -ErrorAction Stop
foreach($function in $Functions){
    . $Function.Path
}

$ExportedFunctionsPath = "$PSScriptRoot\ExportedFunctions\*.ps1"
$ExportedFunctions     = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $ExportedFunctions){
    . $Function.Path
}