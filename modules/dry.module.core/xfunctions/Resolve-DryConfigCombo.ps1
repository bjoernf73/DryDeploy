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

#! Set-DryConfigCombo and Resolve-DryConfigCombo does not make much sense
function Resolve-DryConfigCombo {
    [CmdLetBinding()]
    param (
        [Parameter()]
        [String] 
        $Path,

        [Parameter(Mandatory)]
        [ValidateSet('Environment','Module')]
        [String] 
        $Type
    )
    ol v "Path is: '$path'"
    $ConfirmExistingConfigCombo = $False
    
    try {
        if ($Path) {
            $ConfigDirectory = Resolve-DryFullPath -Path $Path -RootPath $GLOBAL:ScriptPath
        }
        else {
            if ( 
                (($GLOBAL:ConfigCombo."$($Type)Config".Path).Trim() -eq '') -Or 
                ($Null -eq $GLOBAL:ConfigCombo."$($Type)Config".Path)
            ) {
                # Path unspecified, and no path present in curent ConfigCombo
                switch ($ErrorActionPreference) {
                    'Stop' {
                        throw "Path to the '$($Type)Config' is empty. Use -SetConfig to specify the Path"
                    }
                    default {
                        ol w "Path to '$($Type)Config' is empty. Use -SetConfig before you -Plan or -Apply."
                        Return
                    }
                }
                
            }
            else {
                # Path unspecified, but path for the type present in ConfigCombo - use that 
                $ConfigDirectory = $GLOBAL:ConfigCombo."$($Type)Config".Path
                $ConfirmExistingConfigCombo = $True
                
            }
        }

        # Get the RootConfig of the Configuration Repository.
        [PSObject]$ConfigRootConfig = Get-DryRootConfig -Path $ConfigDirectory

        if ($ConfirmExistingConfigCombo) {
            if (-not (Confirm-DryConfigCombo -RootConfig $ConfigRootConfig -ConfigCombo $GLOBAL:ConfigCombo)) {
                throw "Error verifying the Configuration Combo"
            }
        }
        # Set and save
        $GLOBAL:ConfigCombo = Set-DryConfigCombo -RootConfig $ConfigRootConfig -ConfigCombo $GLOBAL:ConfigCombo -Path $ConfigDirectory
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}