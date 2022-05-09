using Namespace System.Collections.Generic
using Namespace System.Collections
<# 
    This module contains functions to resolve, get, modify and show a DryDeploy 
    Plan.  

    Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
    
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
$ClassesPath = "$PSScriptRoot\classes\*.ps1"
$Scripts = Resolve-Path -Path $ClassesPath -ErrorAction Stop
foreach ($Script in $Scripts) {
    . $Script.Path
}

$ExportedFunctionsPath = "$PSScriptRoot\xfunctions\*.ps1"
$Functions = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach ($Function in $Functions) {
    . $Function.Path
}