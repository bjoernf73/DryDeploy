# This module is an action module for use with DryDeploy. It moves a computer 
# object in AD using the dry.module.ad module
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.ad.move/main/LICENSE
# 


$ExportedFunctionsPath = "$PSScriptRoot\ExportedFunctions\*.ps1"
$ExportedFunctions     = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $ExportedFunctions){
    . $Function.Path
}