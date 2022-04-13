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
        [String]$Alias,

        [Parameter(HelpMessage="The Environment (GlobalConfig) that the Alias to get belongs to")]
        [String]$GlobalConfig
    )

    try {
        $DryCredentials = [Credentials]::New($GLOBAL:CredentialsFile)
        if ($GlobalConfig) {
            return [PSCredential] $DryCredentials.GetCredential($Alias,$GlobalConfig)
        }
        else {
            return [PSCredential] $DryCredentials.GetCredential($Alias,$GLOBAL:GlobalConfigName)
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }    
}