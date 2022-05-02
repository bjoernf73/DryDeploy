<# 
 This module provides core functionality for DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.core/main/LICENSE
 
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

function Get-DryQuote {
    [cmdletbinding()]
    param (
    )
    try {
        $QuoteRepo      = ' '
        $Configuration = New-Object PSObject
        $Files         = @(Get-ChildItem -Path $FullPath -Include '*.jsonc','*.json','*.yml','*.yaml' -ErrorAction Stop)

        foreach ($File in $Files) {
            switch ($File.extension) {
                {$_ -in '.json','.jsonc'} {
                    $ConfObject = Get-DryFromJson -Path $File.FullName -ErrorAction Stop  
                }
                {$_ -in '.yml','.yaml'} {
                    $ConfObject = Get-DryFromYaml -Path $File.FullName -ErrorAction Stop 
                }
            }
            $Configuration = (Merge-DryPSObjects -FirstObject $Configuration -SecondObject $ConfObject)
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}