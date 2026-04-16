using Namespace System.Collections.Generic
using Namespace System.Collections
<#
    This module contains functions to resolve, get, modify and show a DryDeploy
    Plan.

    Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
   #>

$ExportedFunctionsPath = "$PSScriptRoot\xfunctions\*.ps1"
$Functions = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $Functions){
    . $Function.Path
}