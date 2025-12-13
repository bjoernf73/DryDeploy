# This module is an action module for use with DryDeploy. It runs a packer 
# null-provdider script in packer.
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.packer.run/main/LICENSE
# 


$ExportedFunctionsPath = "$PSScriptRoot\ExportedFunctions\*.ps1"
$ExportedFunctions = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $ExportedFunctions){
    . $Function.Path
}