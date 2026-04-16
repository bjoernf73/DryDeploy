<#
 This module provides functions to resolve values from expressions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

# Dot source all exported functionscripts
$ExportedFunctionsPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'xfunctions') -ChildPath "*.ps1"
$ExportedFunctions     = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $ExportedFunctions){
    . $Function.Path
}