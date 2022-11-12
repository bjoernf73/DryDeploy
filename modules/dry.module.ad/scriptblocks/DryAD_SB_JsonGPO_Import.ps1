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

[ScriptBlock]$DryAD_SB_JsonGPO_Import = {
    [CmdLetBinding()] 
    Param (
        [String]
        $Name,

        [String]
        $FileName,

        [String]
        $DomainController,

        [Bool]
        $Force,

        [Bool]
        $DefaultPermissions,

        [HashTable]
        $Replacements
    )
    $Result = @($False, $Null, '')
    
    try {
        Import-Module -Name 'dry.ad.gpohelper' -Force -ErrorAction 'Stop' | Out-Null
        
        $GPOExistsAlreadyParams = @{
            Name             = $Name
            DomainController = $DomainController
        }
        [Bool]$GPOExistsAlready = Test-GroupPolicyExistenceInAD @GPOExistsAlreadyParams
    
        If ($GPOExistsAlready -and (-not $Force)) {
            $Result[2] = 'GPO exists already and you didn''t -force (no change)'
            $Result[0] = $True
        }
        Else {
            $ImportGroupPolicyToADParams = @{
                Name                    = $Name
                FileName                = $FileName
                OverwriteExistingPolicy = $Force
                DefaultPermissions      = $DefaultPermissions
                Replacements            = $Replacements
                PerformBackup           = $Force # If we overwrite, we also perform a backup of the existing GPO
                RemoveLinks             = $True
                DoNotLinkGPO            = $True
            }
            
            Import-GroupPolicyToAD @ImportGroupPolicyToADParams
            $Result[0] = $True
            
            If ($GPOExistsAlready -and $Force) {
                $Result[2] = 'An existing GPO was replaced (original renamed)'
            }
            Else {
                $Result[2] = 'The GPO was imported'
            }
        }
        Return $Result
    }
    Catch {
        $Result[0] = $False
        $Result[1] = $_
        $Result[2] = 'The GPO import failed'
        Return $Result    
    }
    Finally {
        @('GPOExistsAlreadyParams',
            'ImportGroupPolicyToADParams',
            'GPOExistsAlready'
        ).ForEach({
                Remove-Variable -Name $_ -ErrorAction Ignore | Out-Null
            })
    }
}

