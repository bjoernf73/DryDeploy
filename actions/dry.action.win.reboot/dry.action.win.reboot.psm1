# This module is an action module for use with DryDeploy. It reboots a
# windows machine
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.win.reboot/main/LICENSE
#


# Dot source all functionscripts - the manifest limits exported functions
$ExportedFunctionsPath = "$PSScriptRoot\ExportedFunctions\*.ps1"
$ExportedFunctions     = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $ExportedFunctions){
    . $Function.Path
}