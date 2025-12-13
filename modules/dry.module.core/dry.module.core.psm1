
<# 
 This module provides core functionality for DryDeploy.

 
#>

$ExportedFunctionsPath = "$PSScriptRoot\xfunctions\*.ps1"
$Functions = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $Functions){
    . $Function.Path
}