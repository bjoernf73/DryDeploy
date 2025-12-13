<#
 This module handles credentials for DryDeploy

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.credential/main/LICENSE
#>

function Get-DryCredential{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,HelpMessage="The Alias of the credential to get")]
        [string]$Alias,

        [Parameter(HelpMessage="The Environment (EnvConfig) that the Alias to get belongs to")]
        [string]$EnvConfig
    )

    try{
        $DryCredentials = [Credentials]::New($GLOBAL:dry_var_global_CredentialsFile)
        if($EnvConfig){
            return [PSCredential] $DryCredentials.GetCredential($Alias,$EnvConfig)
        }
        else{
            return [PSCredential] $DryCredentials.GetCredential($Alias,$GLOBAL:dry_var_global_ConfigCombo.envconfig.name)
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }    
}