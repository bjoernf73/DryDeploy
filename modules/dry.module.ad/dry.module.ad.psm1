Using Module ActiveDirectory
Using Namespace System.Management.Automation.Runspaces
<#  
    This is an AD Config module for use with DryDeploy, or by itself.
    Copyright (C) 2021  Bjørn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.ad/main/LICENSE

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#>

# Dot source all ScriptBlock-scripts, Function-scripts, Classes-scripts
# and ExportedFunction-scripts
$ScriptBlocksPath      = "$PSScriptRoot\scriptblocks\*.ps1"
$FunctionsPath         = "$PSScriptRoot\functions\*.ps1"
$ClassesPath           = "$PSScriptRoot\classes\*.ps1"
$ExportedFunctionsPath = "$PSScriptRoot\xfunctions\*.ps1"

$ScriptBlocks          = Resolve-Path -Path $ScriptBlocksPath -ErrorAction Stop
$Functions             = Resolve-Path -Path $FunctionsPath -ErrorAction Stop
$Classes               = Resolve-Path -Path $ClassesPath -ErrorAction Stop
$ExportedFunctions     = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop

ForEach ($ScriptBlock in $ScriptBlocks) {
    . $ScriptBlock.Path
}
ForEach ($Function in $Functions) {
    . $Function.Path
}
ForEach ($Class in $Classes) {
    . $Class.Path
}
ForEach ($ExportedFunction in $ExportedFunctions) {
    . $ExportedFunction.Path
}