# This module is an action module for use with DryDeploy. It finds the IP 
# of a DHCP resource and updates the resource, so subsequent actions
# may target the resource
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
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

# Dot source all functionscripts - the manifest limits exported functions
$ExportedFunctionsPath = "$PSScriptRoot\ExportedFunctions\*.ps1"
$ExportedFunctions     = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
ForEach ($Function in $ExportedFunctions) {
    . $Function.Path
}