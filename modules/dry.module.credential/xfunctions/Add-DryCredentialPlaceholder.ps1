<#
 This module handles credentials for DryDeploy

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.credential/main/LICENSE
#>

function Add-DryCredentialPlaceholder{
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory,HelpMessage="The Alias of the credential to add")]
        [string]$Alias,

        [Parameter(Mandatory,HelpMessage="The Environment (EnvConfig) for which the placeholder is added")]
        [string]$EnvConfig,

        [ValidateSet('encryptedstring', 'hashicorpvault', 'ansiblevault')]
        [Parameter(Mandatory,HelpMessage="The Environment Name (EnvConfig) for which the credential placeholder is added")]
        [string]$Type,

        [Parameter(HelpMessage="The user name of the credential to add, if specified")]
        [string]$UserName
    )

    try{
        $DryCredentials = [Credentials]::New($GLOBAL:dry_var_global_CredentialsFile)
        if(($UserName) -and ($UserName.Trim() -ne '')){
            $DryCredentials.AddCredentialPlaceholder($Alias,$EnvConfig,$Type,$UserName)
        }
        else{
            $DryCredentials.AddCredentialPlaceholder($Alias,$EnvConfig,$Type)
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }    
}