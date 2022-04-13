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
    [Alias("Get-DryActionPaths")]
    param (
        [Parameter(Mandatory)]
        [PSObject]$Resource,

        [Parameter(Mandatory)]
        [PSObject]$Action,

        [Parameter()]
        [Switch]$NoFiles
    )
    
    try {
        <#
            The Role has a path in the Module. It's full path in the filesystem is resolved. 
            That path is used as the basis of multiple other paths, that are represented by 
            properties in the PSObject returned from this function
        #>
        [String]$ConfigSourcePath = Join-Path -Path $Resource.RolePath -ChildPath $Action.Action

        # determine the slash in paths - backslash on windows, slash on Linux
        $slash = '\'
        if ($PSVersionTable.Platform -eq 'Unix') {
            $slash = '/'
        }
        <#
            A module may contain arbitrary files on any level in a Module's directory structure. 
            Files should be placed at the highest level under which there are configurations that
            may use them. Tecnically, they can be placed at the highest level, even though only
            a single type of a single phase of a single Action of a single Role use them. If, 
            however, variables cannot be used (easily) to represent the differences between 
            different uses (roles, actions, phases, types), there is an option to place the files 
            at any lower level. The ActionOptions-object, returned from this function, will 
            resolve and return all those possible paths. 

            - 'ModuleFilesSourcePath' = Directory 'Files' at the root of the current ModuleConfig 
              (Module). The files may be used by any Role in the Module 

            - 'RoleFilesSourcePath'   = Directory 'Files' at the root of the current Role of the 
              current Module. The files may be used by any of the Role's Actions

            - 'ActionFilesSourcePath' = Directory 'Files' at the root of the current Action of 
              the current Role in the current Module. The files may be used by any Phase and/or 
              Type of that Action in the Role of the Module

            - 'PhaseFilesSourcePath' = Directory 'Files' at the root of the current
              Phase of the current Action of the current Role in the current Module. If the 
              Action is non-phased, 'PhaseFilesSourcePath' = 'ActionFilesSourcePath'.
            
            - 'TypeFilesSourcePath' = Directory 'Files' at the root of the current Type of the 
              current Phase of the current Action of the current Role in the current Module. If 
              the Action is non-typed, 'TypeFilesSourcePath' = 'PhaseFilesSourcePath'. If the 
              Action is non-Phased, 'TypeFilesSourcePath' = 'ActionFilesSourcePath'
        #>
        [String]$ModuleFilesSourcePath = Resolve-DryFullPath -Path "..$($slash)..$($slash)Files" -RootPath $ConfigSourcePath
        if (Test-Path -Path $ModuleFilesSourcePath -ErrorAction Ignore) {
            $LeafFilesSourcePath = $ModuleFilesSourcePath
        }
        [String]$RoleFilesSourcePath   = Resolve-DryFullPath -Path "..$($slash)Files" -RootPath $ConfigSourcePath
        if (Test-Path -Path $RoleFilesSourcePath -ErrorAction Ignore) {
            $LeafFilesSourcePath = $RoleFilesSourcePath
        }
        [String]$ActionFilesSourcePath = Resolve-DryFullPath -Path ".$($slash)Files" -RootPath $ConfigSourcePath
        if (Test-Path -Path $ActionFilesSourcePath -ErrorAction Ignore) {
            $LeafFilesSourcePath = $ActionFilesSourcePath
        }
        
        if ($Action.Phase -gt 0) {
            ol i @('Role'  ,"$($Resource.Role)")
            ol i @('Action',"$($Action.Action)[$($Action.Phase)]")
            [String]$ConfigSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath $Action.Phase
            [String]$PhaseFilesSourcePath = Resolve-DryFullPath -Path ".$($slash)Files" -RootPath $ConfigSourcePath
            if (Test-Path -Path $PhaseFilesSourcePath -ErrorAction Ignore) {
                $LeafFilesSourcePath = $PhaseFilesSourcePath
            }
            [String]$ConfigTargetPath = Join-Path -Path (Join-Path -Path $Resource.ConfigurationTargetPath -ChildPath $Action.Action) -ChildPath $Action.Phase
            # If a ad.import Action is non-Phased, the action type, specified 
            # in the Resource's Options, must be referenced with 'ad.import_type'
            $ActionTypePropertyName = "$($Action.Action)_type"
        }
        else {
            ol i @('Role'  ,"$($Resource.Role)")
            ol i @('Action',"$($Action.Action)")
            [String]$PhaseFilesSourcePath = $ActionFilesSourcePath
            [String]$ConfigTargetPath      = Join-Path -Path $Resource.ConfigurationTargetPath -ChildPath $Action.Action
            [String]$ActionTypePropertyName = "$($Action.Action)_type$($Action.Phase)"
        }
        $ConfigRootPath = $ConfigSourcePath

        if ($NoFiles) {
            return [PSCustomObject]@{
                ConfigTargetPath = $ConfigTargetPath
                ConfigRootPath   = $ConfigRootPath
            }
        }
        else {
            <#
                - The OS Source Path is never Phased, define OSSourcePath 
            #>
            [String]$ConfigOSSourcePath = Join-Path -Path $Resource.OSConfigPath -ChildPath $Action.Action

            $ActionMetaConfigFile   = Join-Path -Path $ConfigSourcePath -ChildPath 'Config.json'
            $OSActionMetaConfigFile = Join-Path -Path $ConfigOSSourcePath -ChildPath 'Config.json'
            
            # Any action must specify a default type
            $ActionMetaConfig       = Get-DryCommentedJson -File $ActionMetaConfigFile -ErrorAction Stop
            if ($Null -eq $ActionMetaConfig.default) {
                throw "The 'default' property is missing from Config.json" 
            }
            elseif ($Null -eq $ActionMetaConfig.supported_types) {
                [String] $ActionType     = $ActionMetaConfig.default
                # This instance of the action does not contain any types, meaning that 
                # the action either does not contain files, or is an action called only 
                # to include the OS specific files. Blank the ConfigSourcePath 
                $ConfigSourcePath = ''
                [String]$TypeFilesSourcePath = ''
            }
            else {
                [String] $ActionType     = $ActionMetaConfig.default
                [Array]  $SupportedTypes = @($ActionMetaConfig.supported_types)


                # Test if the Resource specifies a type for this Action, and modify  
                # ActionType only if specified type is supported - else keep the default 
                if ($Resource.options."$ActionTypePropertyName") {
                    if ($Resource.options."$ActionTypePropertyName" -in $SupportedTypes) {
                        $ActionType = $Resource.options."$ActionTypePropertyName"
                    }
                }

                <#
                    An action may 'follow' another Action's type. For instance, the 'MoveToOU'
                    Action has a 'default' equalling the ad.import 'default' for a specific
                    Role, but if that Role's type is modified
                    by $Resource.options.ad.import_type, then MoveToOU must modify accordingly.
                    The ActionMetaConfig's 'follow_type' property specifies which Action's type
                    to follow 
                #>
                if ($null -ne $ActionMetaConfig.follow_type) {
                    $ResourceFollowType = "$($ActionMetaConfig.follow_type)_type"
                    if ($Resource.Options."$ResourceFollowType") {
                        if ($Resource.options."$ResourceFollowType" -in $SupportedTypes) {
                            $ActionType = $Resource.Options."$ResourceFollowType"
                        }
                    }
                }
                
                $ConfigSourcePath = Join-Path -Path $ConfigSourcePath -ChildPath $ActionType
                [String]$TypeFilesSourcePath = Resolve-DryFullPath -Path ".$($slash)Files" -RootPath $ConfigSourcePath
                if (Test-Path -Path $TypeFilesSourcePath -ErrorAction Ignore) {
                    $LeafFilesSourcePath = $TypeFilesSourcePath
                }
            }

            # Test if OS config should be included for this action
            if ($ActionMetaConfig.include_os_config -eq $true) {
                $OSActionMetaConfig = Get-DryCommentedJson -File $OSActionMetaConfigFile -ErrorAction Stop
                
                [String]$OSActionType     = $OSActionMetaConfig.default
                if ($null -eq $OSActionType) {
                    throw "The OSConfig for Action '$($Action.Action)' has no 'default'"
                }
                [Array]$OSSupportedTypes = @($OSActionMetaConfig.supported_types)
                if (
                    ($Null -eq $OSSupportedTypes) -or 
                    ($OSSupportedTypes.count -eq 0)
                ) {
                    throw "The OSConfig for Action '$($Action.Action)' has no 'supported_types'"
                }

                # Test if the Resource specifies a type for this Action, and modify  
                # OSActionType only if specified type is supported - else keep the default 
                if ($Resource.options."$ActionTypePropertyName") {
                    if ($Resource.options."$ActionTypePropertyName" -in $OSSupportedTypes) {
                        $OSActionType = $Resource.options."$ActionTypePropertyName"
                    }
                }

                # Test if the OSSupportedTypes contains the default type specified on the 
                # Roles MetaConfig for the Action, and modify  OSActionType 
                # only if specified type is supported - else keep the default  
                elseif ($ActionMetaConfig.default -in $OSActionMetaConfig.supported_types) {
                    $OSActionType = $ActionMetaConfig.default
                }
                $ConfigOSSourcePath = Join-Path -Path $ConfigOSSourcePath -ChildPath $OSActionType 
            }
            else {
                $ConfigOSSourcePath = ''
            }

            ol i 'Action source',"$ConfigSourcePath"
            ol i 'Action target',"$ConfigTargetPath"
            ol i 'OS source',"$ConfigOSSourcePath"
            ol i 'Action type',"$ActionType"
            ol i 'Module Files Source',"$ModuleFilesSourcePath"
            ol i 'Role Files Source',"$RoleFilesSourcePath"
            ol i 'Action Files Source',"$ActionFilesSourcePath"
            ol i 'Phase Files Source',"$PhaseFilesSourcePath"
            ol i 'Type Files Source',"$TypeFilesSourcePath"
            ol i 'Leaf Files Source',"$LeafFilesSourcePath"

            # return the paths
            return [PSCustomObject]@{
                ConfigSourcePath      = $ConfigSourcePath
                ConfigOSSourcePath    = $ConfigOSSourcePath
                ConfigTargetPath      = $ConfigTargetPath
                ConfigRootPath        = $ConfigRootPath
                ActionType            = $ActionType
                ModuleFilesSourcePath = $ModuleFilesSourcePath
                RoleFilesSourcePath   = $RoleFilesSourcePath
                ActionFilesSourcePath = $ActionFilesSourcePath
                PhaseFilesSourcePath  = $PhaseFilesSourcePath
                TypeFilesSourcePath   = $TypeFilesSourcePath
                LeafFilesSourcePath   = $LeafFilesSourcePath
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}



<#
            Specific Actions supports 'Options', where a default option is specified 
            in the ModuleConfiguration's Action-specific meta-config (Config.json), 
            which may be overridden for a Resource by specifying supported properties
            in the Resource's 'Options' property. 

            Example meta-config (Action: ProvisionDSC), specifying the default, and 
            the alternate configuration 'RODC' for a Read Only DC: 
            
            {
                "default"                : "Default",
                "supported_types"        : [
                    "Default",
                    "RODC"
                ]
            }

            Example Resource-override, where instead of the 'Default' dsc type, the
            alternate 'RODC' type is selected: 
            
            {
                "Role"   : "DC-AdditionalDomainController",
                "name"                   : "DC002-###ADSite###-###Environment###",
                "network": {
                    "site"               : "S5",
                    "subnet_name"        : "INT5",
                    "ip_address"         : "10.0.5.12"
                }
                "options": {
                    "provisiondsc_type1" : "RODC",
                    "provisiondsc_type2" : "Default",
                    "ad.import_type"      : "domain",
                    "clonevm_type"       : "cpu8mem8"
                }
            }

            The Default will be selected if the option is not specified on the Resource.

            The Types are expected to have their configuration in a subfolder named after 
            the type. The 'default' type has it's files in a subfolder 'Default', the 
            RODC type has it's files in a subfolder 'RODC'. 

            If a configuration_type is specified, but it is not in the 'supported_types', 
            the default is selected. 
        #>