<#
 This module handles credentials for DryDeploy

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.credential/main/LICENSE
#>

function Add-DryCredential{
    [CmdLetBinding(DefaultParameterSetName='Credential')]
    param(
        [Parameter(Mandatory,HelpMessage="The Alias the credential to add")]
        [string]$Alias,

        [Parameter(Mandatory,ParameterSetName="Credential",HelpMessage="The name, or 'alias', of the credential to add")]
        [PSCredential]$Credential,

        [Parameter(Mandatory,ParameterSetName="UserNameAndPassword",HelpMessage="The user name of the credential to add")]
        [string]$UserName,

        [Parameter(Mandatory,ParameterSetName="UserNameAndPassword",HelpMessage="The password of the credential to add")]
        [string]$Password
    )

    try{
        $DryCredentials = [Credentials]::New($GLOBAL:dry_var_global_CredentialsFile)
        # make sure Global vars exist
        if($null -eq $GLOBAL:dry_var_global_ConfigCombo.envconfig.name){
            throw "The ConfigCombo.envconfig.name is null"
        }
        if($null -eq $GLOBAL:dry_var_global_Configuration.CredentialsType){
            throw "Missing global variable 'CredentialsType' (defined in DryDeploy.ps1)"
        }
        
        switch($PsCmdlet.ParameterSetName){
            "Credential" { 
                $DryCredentials.AddCredential($Alias,$GLOBAL:dry_var_global_ConfigCombo.envconfig.name,$GLOBAL:dry_var_global_Configuration.CredentialsType,$Credential)
            }
            "UserNameAndPassword" {
                $DryCredentials.AddCredential($Alias,$GLOBAL:dry_var_global_ConfigCombo.envconfig.name,$GLOBAL:dry_var_global_Configuration.CredentialsType,$UserName,$Password)
            }
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }    
}