<#
 This module provides query functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.sessions/main/LICENSE
#>

$FunctionsPath = "$PSScriptRoot\xfunctions\*.ps1"
$Functions     = Resolve-Path -Path $FunctionsPath -ErrorAction Stop
foreach($function in $Functions){
    . $Function.Path
}