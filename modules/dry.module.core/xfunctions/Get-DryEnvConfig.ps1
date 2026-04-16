<#
 This module provides core functionality for DryDeploy.


#>

function Get-DryEnvConfig{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ConfigCombo,

        [Parameter(Mandatory)]
        [PSCustomObject]$Paths
    )
    try{
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            EnvConfig

            The EnvConfig describes the environment into which you deploy your module. The EnvConfig
            is a directory or repository containing three sub directories;

            1. 'CoreConfig' which containing configurations DryDeploy needs to Plan and Apply

            2. 'UserConfig' which is user definable. Make any structure you'd like, and resolve in
                params to your Actions

            3. 'BaseConfig' has a file structure like Roles. We don't "pick up" those
                configs here, since they may be DSC-files, Active Directory defintions, and such -
                just record the path to the folder. Actions that inherit BaseConfigs, will pick those
                files up, and include in your Action config.

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        $Configuration = $null
        $Configuration = [PSCustomObject]@{
            CoreConfig = $null
            UserConfig = $null
            Paths = $Paths
        }
        $Configuration.CoreConfig = Get-DryConfigData -Path (Join-Path -Path $ConfigCombo.envconfig.path -ChildPath 'coreconfig') -ErrorAction Stop
        if(Test-Path -Path (Join-Path -Path $ConfigCombo.envconfig.path -ChildPath 'userconfig')){
            $Configuration.UserConfig = Get-DryConfigData -Path (Join-Path -Path $ConfigCombo.envconfig.path -ChildPath 'userconfig') -Configuration $Configuration -ErrorAction Stop
        }
        return $Configuration
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}