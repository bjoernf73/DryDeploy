<#
 This module handles credentials for DryDeploy

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.credential/main/LICENSE
 
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

function Get-DryCredential {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,HelpMessage="The Alias of the credential to get")]
        [string]$Alias,

        [Parameter(HelpMessage="The Environment (EnvConfig) that the Alias to get belongs to")]
        [string]$EnvConfig
    )

    try {
        $DryCredentials = [Credentials]::New($GLOBAL:dry_var_global_CredentialsFile)
        if ($EnvConfig) {
            return [PSCredential] $DryCredentials.GetCredential($Alias,$EnvConfig)
        }
        else {
            return [PSCredential] $DryCredentials.GetCredential($Alias,$GLOBAL:dry_var_global_ConfigCombo.envconfig.name)
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }    
}