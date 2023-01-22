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

function New-DryItem {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [String[]]$Items,

        [Parameter(Mandatory)]
        [ValidateSet('Directory','File')]
        [String]$ItemType
    )

    try {
        foreach ($Item in $Items) {
            if (Test-Path -Path "$Item" -ErrorAction Ignore) {
                $ExistingItem = Get-Item -Path "$Item" -ErrorAction Stop
                switch ($ItemType) {
                    'Directory' {
                        if ($false -eq $ExistingItem.PSIsContainer) {
                            throw "Item '$($ExistingItem.FullName)' is of wrong type"
                        }
                    }
                    'File' {
                        if ($true -eq $ExistingItem.PSIsContainer) {
                            throw "Item '$($ExistingItem.FullName)' is of wrong type"
                        }
                    }
                }
            }
            else {
                New-Item -ItemType $ItemType -Path "$Item" -Force | Out-Null
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $ExistingItem = $null
    }
}