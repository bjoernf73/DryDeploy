# This module is an action module for use with DryDeploy. It uses the 
# VMware vSphere API to clone a template, and customize the new vm. 
#
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.vsphere.clonevm/main/LICENSE
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Import the VMware.PowerCLI module 
try {
    Import-Module -Name 'VMware.PowerCLI' -Verbose:$false -ErrorAction 'Stop'
} 
catch [System.Management.Automation.RuntimeException] {
    if (-not($_.Exception.Message -eq 'The VMware.ImageBuilder module is not currently supported on the Core edition of PowerShell.')) {
        throw $_
    }
    else {
        ol w "Note that the VMware.ImageBuilder module is not currently supported on the Core edition of PowerShell."
    }
} 
catch {
    throw $_
}
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false

# Dot source all functionscripts - the manifest limits exported functions
$FunctionsPath = "$PSScriptRoot\Functions\*.ps1"
$Functions     = Resolve-Path -Path $FunctionsPath -ErrorAction Stop
ForEach ($function in $Functions) {
    . $Function.Path
}

$ExportedFunctionsPath = "$PSScriptRoot\ExportedFunctions\*.ps1"
$ExportedFunctions     = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
ForEach ($function in $ExportedFunctions) {
    . $Function.Path
}