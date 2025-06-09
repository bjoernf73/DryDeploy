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

function Resolve-DryActionOptions{
    [CmdletBinding()]
    param( 
        [Parameter(Mandatory)]
        [PSObject]$Action,

        [Parameter(Mandatory)]
        [PSObject]$Configuration,

        [Parameter(Mandatory)]
        [PSObject]$ConfigCombo,

        [Parameter()]
        [Switch]$NoFiles
    )
    
    try{
        <#
            Example Paths in Configuration: 
            
            RootWorkingDirectory  : C:\Users\user\DryDeploy
            PlanFile              : C:\Users\user\DryDeploy\dry_deploy_plan.json
            ResourcesFile         : C:\Users\user\DryDeploy\dry_deploy_resources.json
            ConfigComboFile       : C:\Users\user\DryDeploy\dry_deploy_config_combo.json
            UserOptionsFile       : C:\Users\user\DryDeploy\UserOptions.json
            TempConfigsDir        : C:\Users\user\DryDeploy\TempConfigs
            ArchiveDir            : C:\Users\user\DryDeploy\Archived
            SystemOptionsFile     : C:\GITs\DRY\DryDeploy\SystemOptions.json
            BaseConfigDirectory   : C:\GITs\DRY\EnvConfigs\utv.local\BaseConfig
            ModuleConfigDirectory : C:\GITs\DRY\ModuleConfigs\DomainRoot\
        #>

        <#
            The Action has a path in the ModuleConfig or in the BaseConfig.
        #>
        [string]$ConfigTargetPath = Join-Path -Path $Configuration.Paths.TempConfigsDir -ChildPath $ConfigCombo.envconfig.name
        [string]$ConfigTargetPath = Join-Path -Path $ConfigTargetPath -ChildPath $Action.ResourceName
        [string]$RoleTargetRootPath = $ConfigTargetPath
        [string]$ConfigTargetPath = Join-Path -Path $ConfigTargetPath -ChildPath $Action.Action
        [string]$ConfigTargetPath = Join-Path -Path $ConfigTargetPath -ChildPath $Action.Source

        switch($Action.source){
            'role'{
                [string]$RolesConfigSourcePath = Join-Path -Path $Configuration.Paths.ModuleConfigDirectory -ChildPath 'Roles'
                [string]$RoleConfigSourcePath  = Join-Path -Path $RolesConfigSourcePath -ChildPath $Action.Role
                [string]$ConfigSourcePath      = Join-Path -Path $RoleConfigSourcePath -ChildPath $Action.Action

                [string]$ModuleFilesSourcePath = Join-Path -Path $Configuration.Paths.ModuleConfigDirectory -ChildPath 'Files'
                [string]$RoleFilesSourcePath   = Join-Path -Path $RoleConfigSourcePath -ChildPath 'Files'
                [string]$ActionFilesSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath 'Files'
                if($Action.Phase -gt 0){
                    [string]$ConfigSourcePath       = Join-Path -Path $ConfigSourcePath -ChildPath $Action.Phase
                    [string]$PhaseFilesSourcePath   = Join-Path -Path $ConfigSourcePath -ChildPath 'Files'
                    [string]$ActionTypePropertyName = "$($Action.Action)_type$($Action.Phase)"
                    [string]$ConfigTargetPath = Join-Path -Path $ConfigTargetPath -ChildPath $Action.Phase
                }
                else{
                    [string]$ActionTypePropertyName = "$($Action.Action)_type"
                }
                [string]$ActionMetaConfigFile = Join-Path -Path $ConfigSourcePath -ChildPath 'Config.json'

            }
            'base'{
                [string]$BaseConfigSourcePath = Join-Path -Path $Configuration.Paths.BaseConfigDirectory -ChildPath $Action.Resource.BaseConfig
                [string]$ConfigSourcePath     = Join-Path -Path $BaseConfigSourcePath -ChildPath $Action.Action
                
                [string]$RoleFilesSourcePath   = Join-Path -Path $BaseConfigSourcePath -ChildPath 'Files'
                [string]$ActionFilesSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath 'Files'
                if($Action.Phase -gt 0){
                    [string]$ConfigSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath $Action.Phase
                    [string]$PhaseFilesSourcePath   = Join-Path -Path $ConfigSourcePath -ChildPath 'Files'
                    [string]$ActionTypePropertyName = "$($Action.Action)_type$($Action.Phase)"
                    [string]$ConfigTargetPath = Join-Path -Path $ConfigTargetPath -ChildPath $Action.Phase
                }
                else{
                    [string]$ActionTypePropertyName = "$($Action.Action)_type"
                }
                [string]$ActionMetaConfigFile = Join-Path -Path $ConfigSourcePath -ChildPath 'Config.json'
            }
        }


        <#
            Resolve all credentials 
        #>
        $Credentials = $null
        $Credentials = New-Object -TypeName PSCustomObject
        $c = 0
        $Action.Credentials.PSObject.Properties.foreach({$c++})
        for ($CredCount = 1; $CredCount -le $c; $CredCount++){
            $GetCredentialsParams = @{
                Alias     = $Action.credentials."Credential$CredCount" 
                EnvConfig = $ConfigCombo.envconfig.name
            }
            $AddMemberParams = @{
                MemberType = 'NoteProperty' 
                Name       = "Credential$CredCount" 
                Value      = (Get-DryCredential @GetCredentialsParams)
            }
            $Credentials | Add-Member @AddMemberParams
        }

        # Any action must specify a default type
        if(Test-Path -Path $ActionMetaConfigFile -ErrorAction ignore){
            $ActionMetaConfig = Get-DryFromJson -File $ActionMetaConfigFile
            if($ActionMetaConfig.default -and $ActionMetaConfig.supported_types){
                [string]$ActionType = $ActionMetaConfig.default
                [array]$SupportedTypes = @($ActionMetaConfig.supported_types)

                # Test if the Resource specifies a type for this Action, and modify  
                # ActionType only if specified type is supported - else keep the default 
                if($Action.Resource.options."$ActionTypePropertyName"){
                    if($Action.Resource.options."$ActionTypePropertyName" -in $SupportedTypes){
                        $ActionType = $Action.Resource.options."$ActionTypePropertyName"
                    }
                }

                
                [string]$ConfigSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath $ActionType
                [string]$TypeFilesSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath 'Files'
                [string]$TypeMetaConfigFile = Join-Path -Path $ConfigSourcePath -ChildPath 'Config.json'
                [PSCustomObject]$TypeMetaConfig = Get-DryFromJson -Path $TypeMetaConfigFile
                
            }
            <#
                An action may 'follow' another Action's type. For instance, the 'MoveToOU'
                Action has a 'default' equalling the ad.import 'default' for a specific
                Role, but if that Role's type is modified by $Action.Resource.options.ad.import_type,
                then MoveToOU must modify accordingly. The ActionMetaConfig's 'follow_type' property 
                specifies which Action's type to follow 
            #>
            if($ActionMetaConfig.follow_type){
                $ActionType = $ActionMetaConfig.default
                $FollowType = $ActionMetaConfig.follow_type
                if($Action.Resource.Options."$FollowType"){
                    $ActionType = $Action.Resource.Options."$FollowType"
                }
            }
        }

        # for actions run in wsl, convert the path to it's wsl equivalent
        $WslConfigSourcePath = ('/mnt/' + $ConfigSourcePath.substring(0,1).tolower() +  $($ConfigSourcePath.substring(2) -replace '\\','/')) -replace '//','/'
        $WslConfigTargetPath = ('/mnt/' + $ConfigTargetPath.substring(0,1).tolower() +  $($ConfigTargetPath.substring(2) -replace '\\','/')) -replace '//','/'


        if($TypeMetaConfig.target_expression){
            [string]$Target = Invoke-Expression -Command $TypeMetaConfig.target_expression 
        }
        else{
            # dhcp da? hvordan gjør vi det? 
            [string]$Target = $Action.Resource.Resolved_Network.ip_address
        }

        # Create the target folder
        if(-not (Test-Path -Path $ConfigTargetPath -ErrorAction Ignore)){
            New-Item -Path $ConfigTargetPath -ItemType Directory -Confirm:$false -Force | Out-Null
        }

        $OptionsObject = New-Object -TypeName PSCustomObject
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'ActionType' -Value $ActionType
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'ConfigTargetPath' -Value $ConfigTargetPath
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'WslConfigTargetPath' -Value $WslConfigTargetPath
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'ConfigSourcePath' -Value $ConfigSourcePath
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'WslConfigSourcePath' -Value $WslConfigSourcePath
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'Credentials' -Value $Credentials
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'Target' -Value $Target
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'RoleTargetRootPath' -Value $RoleTargetRootPath

        if($ActionMetaConfig){
            $OptionsObject | Add-Member -MemberType NoteProperty -Name 'ActionMetaConfig' -Value $ActionMetaConfig
        }

        if($TypeMetaConfig){
            $OptionsObject | Add-Member -MemberType NoteProperty -Name 'TypeMetaConfig' -Value $TypeMetaConfig
        }

        if($ModuleFilesSourcePath){
            if(Test-Path -Path $ModuleFilesSourcePath -ErrorAction Ignore){
                $OptionsObject | Add-Member -MemberType NoteProperty -Name 'ModuleFilesSourcePath' -Value $ModuleFilesSourcePath
            }
        }
        if($RoleFilesSourcePath){
            if(Test-Path -Path $RoleFilesSourcePath -ErrorAction Ignore){
                $OptionsObject | Add-Member -MemberType NoteProperty -Name 'RoleFilesSourcePath' -Value $RoleFilesSourcePath
            }
        }
        if($ActionFilesSourcePath){
            if(Test-Path -Path $ActionFilesSourcePath -ErrorAction Ignore){
                $OptionsObject | Add-Member -MemberType NoteProperty -Name 'ActionFilesSourcePath' -Value $ActionFilesSourcePath
            }
        }
        if($PhaseFilesSourcePath){
            if(Test-Path -Path $PhaseFilesSourcePath -ErrorAction Ignore){
                $OptionsObject | Add-Member -MemberType NoteProperty -Name 'PhaseFilesSourcePath' -Value $PhaseFilesSourcePath
            }
        }
        if($TypeFilesSourcePath){
            if(Test-Path -Path $TypeFilesSourcePath -ErrorAction Ignore){
                $OptionsObject | Add-Member -MemberType NoteProperty -Name 'TypeFilesSourcePath' -Value $TypeFilesSourcePath
            }
        }
        if($TypeMetaConfigFile){
            $OptionsObject | Add-Member -MemberType NoteProperty -Name 'TypeMetaConfigFile' -Value $TypeMetaConfigFile
        }
        
        
        if($ActionMetaConfig.vars){
            # There are variables to be resolved for the Action
            $ResolveDryVarParams = @{
                Variables     = $ActionMetaConfig.vars
                Action        = $Action
                Resource      = $Action.Resource
                Configuration = $Configuration
                Credentials   = $Credentials
                Resolved      = $OptionsObject
            }
            $MetaConfigVars = Resolve-DryVariables @ResolveDryVarParams
            $ResolveDryVarParams = $null
        }
        elseif($TypeMetaConfig.vars){
            # There are variables to be resolved for the Action Type
            $ResolveDryVarParams = @{
                Variables     = $TypeMetaConfig.vars
                Action        = $Action
                Resource      = $Action.Resource
                Configuration = $Configuration
                Credentials   = $Credentials
                Resolved      = $OptionsObject
            }
            $MetaConfigVars = Resolve-DryVariables @ResolveDryVarParams
            $ResolveDryVarParams = $null
        }

        if($MetaConfigVars){
            $OptionsObject | Add-Member -MemberType NoteProperty -Name 'Vars' -Value $MetaConfigVars
        }
        return $OptionsObject
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}