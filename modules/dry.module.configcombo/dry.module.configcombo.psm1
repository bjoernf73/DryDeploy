<#
 This module provides core functionality for DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
#>

$ScriptBlocksPath = "$PSScriptRoot\scriptblocks\*.ps1"
$ScriptBlocks = Resolve-Path -Path $ScriptBlocksPath -ErrorAction Stop
foreach($ScriptBlock in $ScriptBlocks){
    . $ScriptBlock.Path
}

$ExportedFunctionsPath = "$PSScriptRoot\xfunctions\*.ps1"
$Functions = @(Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop)
foreach($function in $Functions){
    . $Function.Path
}