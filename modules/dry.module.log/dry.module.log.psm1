<#
 This module is contains logging and console output functions for DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.query/main/LICENSE
#>

# Dot source all functionscripts
$FunctionsPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'functions') -ChildPath "*.ps1"
$Functions     = Resolve-Path -Path $FunctionsPath -ErrorAction Stop
foreach($function in $Functions){
    . $Function.Path
}

# Dot source all exported functionscripts
$ExportedFunctionsPath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'xfunctions') -ChildPath "*.ps1"
$ExportedFunctions     = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $ExportedFunctions){
    . $Function.Path
}