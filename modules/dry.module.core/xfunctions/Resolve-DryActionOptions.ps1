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

function Resolve-DryActionOptions {
    [CmdletBinding()]
    param ( 
        [Parameter(Mandatory)]
        [PSObject]$Action,

        [Parameter(Mandatory)]
        [PSObject]$Configuration,

        [Parameter(Mandatory)]
        [PSObject]$ConfigCombo,

        [Parameter()]
        [Switch]$NoFiles
    )
    
    try {
        <#
            Paths in Configuration: 
            
            RootWorkingDirectory  : C:\Users\bjoernf\DryDeploy
            PlanFile              : C:\Users\bjoernf\DryDeploy\dry_deploy_plan.json
            ResourcesFile         : C:\Users\bjoernf\DryDeploy\dry_deploy_resources.json
            ConfigComboFile       : C:\Users\bjoernf\DryDeploy\dry_deploy_config_combo.json
            UserOptionsFile       : C:\Users\bjoernf\DryDeploy\UserOptions.json
            TempConfigsDir        : C:\Users\bjoernf\DryDeploy\TempConfigs
            ArchiveDir            : C:\Users\bjoernf\DryDeploy\Archived
            SystemOptionsFile     : C:\GITs\DRY\DryDeploy\SystemOptions.json
            BaseConfigDirectory   : C:\GITs\DRY\EnvConfigs\utv.local\BaseConfig
            ModuleConfigDirectory : C:\GITs\DRY\ModuleConfigs\DomainRoot\
        #>

        <#
            The Action has a path in the ModuleConfig or in the BaseConfig.
        #>
        [String]$ConfigTargetPath = Join-Path -Path $Configuration.Paths.TempConfigsDir -ChildPath $ConfigCombo.envconfig.name
        [String]$ConfigTargetPath = Join-Path -Path $ConfigTargetPath -ChildPath $Action.ResourceName
        [String]$ConfigTargetPath = Join-Path -Path $ConfigTargetPath -ChildPath $Action.Action
        [String]$ConfigTargetPath = Join-Path -Path $ConfigTargetPath -ChildPath $Action.Source

        switch ($Action.source) {
            'role' {
                [String]$RolesConfigSourcePath = Join-Path -Path $Configuration.Paths.ModuleConfigDirectory -ChildPath 'roles'
                [String]$RoleConfigSourcePath  = Join-Path -Path $RolesConfigSourcePath -ChildPath $Action.Role
                [String]$ConfigSourcePath      = Join-Path -Path $RoleConfigSourcePath -ChildPath $Action.Action

                [String]$ModuleFilesSourcePath = Join-Path -Path $Configuration.Paths.ModuleConfigDirectory -ChildPath 'files'
                [String]$RoleFilesSourcePath   = Join-Path -Path $RoleConfigSourcePath -ChildPath 'files'
                [String]$ActionFilesSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath 'files'
                if ($Action.Phase -gt 0) {
                    [String]$ConfigSourcePath       = Join-Path -Path $ConfigSourcePath -ChildPath $Action.Phase
                    [String]$PhaseFilesSourcePath   = Join-Path -Path $ConfigSourcePath -ChildPath 'files'
                    [String]$ActionTypePropertyName = "$($Action.Action)_type$($Action.Phase)"
                    [String]$ConfigTargetPath = Join-Path -Path $ConfigTargetPath -ChildPath $Action.Phase
                }
                else {
                    [String]$ActionTypePropertyName = "$($Action.Action)_type"
                }
                [String]$ActionMetaConfigFile = Join-Path -Path $ConfigSourcePath -ChildPath 'Config.json'

            }
            'base' {
                [String]$BaseConfigSourcePath = Join-Path -Path $Configuration.Paths.BaseConfigDirectory -ChildPath $Action.Resource.BaseConfig
                [String]$ConfigSourcePath     = Join-Path -Path $BaseConfigSourcePath -ChildPath $Action.Action
                
                [String]$RoleFilesSourcePath   = Join-Path -Path $BaseConfigSourcePath -ChildPath 'files'
                [String]$ActionFilesSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath 'files'
                if ($Action.Phase -gt 0) {
                    [String]$ConfigSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath $Action.Phase
                    [String]$PhaseFilesSourcePath   = Join-Path -Path $ConfigSourcePath -ChildPath 'files'
                    [String]$ActionTypePropertyName = "$($Action.Action)_type$($Action.Phase)"
                    [String]$ConfigTargetPath = Join-Path -Path $ConfigTargetPath -ChildPath $Action.Phase
                }
                else {
                    [String]$ActionTypePropertyName = "$($Action.Action)_type"
                }
                [String]$ActionMetaConfigFile = Join-Path -Path $ConfigSourcePath -ChildPath 'Config.json'
            }
        }

        <#
            Resolve all credentials 
        #>
        $ResolvedCredentials = $null
        $ResolvedCredentials = New-Object -TypeName PSCustomObject
        $c = 0
        $Action.Credentials.PSObject.Properties.ForEach({$c++})
        for ($CredCount = 1; $CredCount -le $c; $CredCount++) {
            $ResolvedCredentials | Add-Member -MemberType NoteProperty -Name "Credential$CredCount" -Value (Get-DryCredential -Alias $Action.credentials."Credential$CredCount" -EnvConfig $ConfigCombo.envconfig.name)
        }
        $Action.Credentials = $ResolvedCredentials

        # Any action must specify a default type
        if (Test-Path -Path $ActionMetaConfigFile -ErrorAction ignore) {
            $ActionMetaConfig = Get-DryFromJson -File $ActionMetaConfigFile
            if ($ActionMetaConfig.default -and $ActionMetaConfig.supported_types) {
                [String]$ActionType = $ActionMetaConfig.default
                [Array]$SupportedTypes = @($ActionMetaConfig.supported_types)

                # Test if the Resource specifies a type for this Action, and modify  
                # ActionType only if specified type is supported - else keep the default 
                if ($Action.Resource.options."$ActionTypePropertyName") {
                    if ($Action.Resource.options."$ActionTypePropertyName" -in $SupportedTypes) {
                        $ActionType = $Action.Resource.options."$ActionTypePropertyName"
                    }
                }

                <#
                    An action may 'follow' another Action's type. For instance, the 'MoveToOU'
                    Action has a 'default' equalling the ad.import 'default' for a specific
                    Role, but if that Role's type is modified by $Action.Resource.options.ad.import_type,
                    then MoveToOU must modify accordingly. The ActionMetaConfig's 'follow_type' property 
                    specifies which Action's type to follow 
                #>
                #! doesn't really work. If an action defined in BaseConfig needs to follow the type
                #! of an action in the RoleConfig, for instance ad.import, and perhaps a specific 
                #! phase of that action, then this fails. However, what if one role has 2 phases
                #! of ad.import, and another is unphased? grmpf
                if ($null -ne $ActionMetaConfig.follow_type) {
                    $ResourceFollowType = "$($ActionMetaConfig.follow_type)_type"
                    if ($Action.Resource.Options."$ResourceFollowType") {
                        if ($Action.Resource.options."$ResourceFollowType" -in $SupportedTypes) {
                            $ActionType = $Action.Resource.Options."$ResourceFollowType"
                        }
                    }
                }
                [String]$ConfigSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath $ActionType
                [String]$TypeFilesSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath 'files'
                [String]$TypeMetaConfigFile = Join-Path -Path $ConfigSourcePath -ChildPath 'Config.json'
                [PSCustomObject]$TypeMetaConfig = Get-DryFromJson -Path $TypeMetaConfigFile
                
            }
            else {

            } 
        }

        if ($TypeMetaConfig.vars) {
            # There are variables to be resolved for the Action
            $ResolveDryVarParams = @{
                Variables     = $TypeMetaConfig.vars
                Action        = $Action
                Resource      = $Action.Resource
                Configuration = $Configuration
            }
            $TypeMetaConfigVars = Resolve-DryVariables @ResolveDryVarParams
            $ResolveDryVarParams = $null
        }

        $OptionsObject = New-Object -TypeName PSCustomObject
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'ActionType' -Value $ActionType
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'ConfigTargetPath' -Value $ConfigTargetPath
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'ConfigSourcePath' -Value $ConfigSourcePath
        $OptionsObject | Add-Member -MemberType NoteProperty -Name 'Credentials' -Value $ResolvedCredentials
        
        if ($ModuleFilesSourcePath) {
            if (Test-Path -Path $ModuleFilesSourcePath -ErrorAction Ignore) {
                $OptionsObject | Add-Member -MemberType NoteProperty -Name 'ModuleFilesSourcePath' -Value $ModuleFilesSourcePath
            }
        }
        if ($RoleFilesSourcePath) {
            if (Test-Path -Path $RoleFilesSourcePath -ErrorAction Ignore) {
                $OptionsObject | Add-Member -MemberType NoteProperty -Name 'RoleFilesSourcePath' -Value $RoleFilesSourcePath
            }
        }
        if ($ActionFilesSourcePath) {
            if (Test-Path -Path $ActionFilesSourcePath -ErrorAction Ignore) {
                $OptionsObject | Add-Member -MemberType NoteProperty -Name 'ActionFilesSourcePath' -Value $ActionFilesSourcePath
            }
        }
        if ($PhaseFilesSourcePath) {
            if (Test-Path -Path $PhaseFilesSourcePath -ErrorAction Ignore) {
                $OptionsObject | Add-Member -MemberType NoteProperty -Name 'PhaseFilesSourcePath' -Value $PhaseFilesSourcePath
            }
        }
        if ($TypeFilesSourcePath) {
            if (Test-Path -Path $TypeFilesSourcePath -ErrorAction Ignore) {
                $OptionsObject | Add-Member -MemberType NoteProperty -Name 'TypeFilesSourcePath' -Value $TypeFilesSourcePath
            }
        }
        if ($TypeMetaConfigFile) {
            $OptionsObject | Add-Member -MemberType NoteProperty -Name 'TypeMetaConfigFile' -Value $TypeMetaConfigFile
        }
        if ($TypeMetaConfigVars) {
            $OptionsObject | Add-Member -MemberType NoteProperty -Name 'Vars' -Value $TypeMetaConfigVars
        }
        
        #ol -Type 'i' -MsgObject $OptionsObject -MsgTitle "Resolved Options"
        return $OptionsObject
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}