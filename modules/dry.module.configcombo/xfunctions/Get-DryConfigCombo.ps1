<#
 This module provides core functionality for DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
#>

function Get-DryConfigCombo{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [PSCustomObject]$SystemOptions,

        [Parameter(Mandatory)]
        [PSCustomObject]$Platform,

        [Parameter(HelpMessage="Ensures that existing EnvConfig isn't read if it is being replaced. Works
        bad to try to read it if it doesn't exist anymore - the read fails and you're unable to replace it")]
        [switch]$NewEnvConfig,

        [Parameter(HelpMessage="Ensures that existing ModuleConfig isn't read if it is being replaced. Works
        bad to try to read it if it doesn't exist anymore - the read fails and you're unable to replace it")]
        [switch]$NewModuleConfig
    )
    try{
        $SystemDependencies = $SystemOptions.dependencies."$($Platform.platform)"."$($Platform.edition)"
        # Create the PSCustomObject
        $ConfigCombo = [PSCustomObject]@{
            name                     = 'default'
            path                     = "$Path"
            platform                 = $Platform.platform
            edition                  = $Platform.edition
            envconfig                = [PSCustomObject]@{ name = ''; type = 'environment';  guid = ''; path = $null; description = ''; dependencies_hash = ''; dependencies = $null; coreconfigpath = $null; userconfigpath = $null; BaseConfigPath = $null}
            moduleconfig             = [PSCustomObject]@{ name = ''; type = 'module';       guid = ''; path = $null; description = ''; dependencies_hash = ''; dependencies = $null; buildpath = $null; rolespath = $null; credentialspath = $null}
            systemconfig             = [PSCustomObject]@{ name = ''; type = 'system';       interactive = $false;                      dependencies_hash = ''; dependencies = $null}
        }

        $ConfigCombo.systemconfig.name = 'DryDeploy'
        if($null -ne $SystemDependencies){
            $ConfigCombo.systemconfig.dependencies = $SystemDependencies
        }
        # add methods to the object
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'Exists'      -Value $dry_core_sb_configcombo_exists
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'Read'        -Value $dry_core_sb_configcombo_read
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'Save'        -Value $dry_core_sb_configcombo_save
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'CalcDepHash' -Value $dry_core_sb_configcombo_calcdephash
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'TestDepHash' -Value $dry_core_sb_configcombo_testdephash
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'Change'      -Value $dry_core_sb_configcombo_change
        $ConfigCombo | Add-Member -MemberType ScriptMethod -Name 'Show'        -Value $dry_core_sb_configcombo_show

        if($ConfigCombo.Exists()){
            $ConfigCombo.Read($NewEnvConfig,$NewModuleConfig)
        }
        else{
            $ConfigCombo.Save()
        }
        return $ConfigCombo
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}