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

function Add-DryCredential {
    [CmdLetBinding(DefaultParameterSetName='Credential')]
    param (
        [Parameter(Mandatory,HelpMessage="The Alias the credential to add")]
        [String]$Alias,

        [Parameter(Mandatory,ParameterSetName="Credential",HelpMessage="The name, or 'alias', of the credential to add")]
        [PSCredential]$Credential,

        [Parameter(Mandatory,ParameterSetName="UserNameAndPassword",HelpMessage="The user name of the credential to add")]
        [String]$UserName,

        [Parameter(Mandatory,ParameterSetName="UserNameAndPassword",HelpMessage="The password of the credential to add")]
        [String]$Password
    )

    try {
        $DryCredentials = [Credentials]::New($GLOBAL:dry_var_global_CredentialsFile)
        # make sure Global vars exist
        if ($null -eq $GLOBAL:dry_var_global_ConfigCombo.envconfig.name) {
            throw "The ConfigCombo.envconfig.name is null"
        }
        if ($null -eq $GLOBAL:dry_var_global_Configuration.CredentialsType) {
            throw "Missing global variable 'CredentialsType' (defined in DryDeploy.ps1)"
        }
        
        switch ($PsCmdlet.ParameterSetName) {
            "Credential"  { 
                $DryCredentials.AddCredential($Alias,$GLOBAL:dry_var_global_ConfigCombo.envconfig.name,$GLOBAL:dry_var_global_Configuration.CredentialsType,$Credential)
            }
            "UserNameAndPassword"  {
                $DryCredentials.AddCredential($Alias,$GLOBAL:dry_var_global_ConfigCombo.envconfig.name,$GLOBAL:dry_var_global_Configuration.CredentialsType,$UserName,$Password)
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }    
}