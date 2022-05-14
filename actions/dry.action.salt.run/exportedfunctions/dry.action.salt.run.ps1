Function dry.action.salt.run {
    [CmdletBinding()]  
    Param (
        [Parameter(Mandatory,HelpMessage="The resolved action object")]
        [PSObject]$Action,

        [Parameter(Mandatory,HelpMessage="The resolved resource object")]
        [PSObject]$Resource,

        [Parameter(Mandatory,HelpMessage="The resolved environment configuration object")]
        [PSObject]$Configuration,

        [Parameter(Mandatory,HelpMessage="ResourceVariables contains resolved variable values from the configurations common_variables and resource_variables combined")]
        [System.Collections.Generic.List[PSObject]]$ResourceVariables,

        [Parameter(Mandatory=$False,HelpMessage="Hash directly from the command line to be added as parameters to the function that iniates the action")]
        [HashTable]$ActionParams
    )
    Try {
        $Location = Get-Location
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   OPTIONS
        #
        #   Resolve sources, temporary target folders, and other options 
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $OptionsObject       = Resolve-DryActionOptions -Resource $Resource -Action $Action
        $ConfigSourcePath    = $OptionsObject.ConfigSourcePath
        $ConfigOSSourcePath  = $OptionsObject.ConfigOSSourcePath
        $ConfigTargetPath    = $OptionsObject.ConfigTargetPath
        
        [String]$SaltMetaConfigFile   = (Get-ChildItem -Path "$ConfigSourcePath\*" -Include *.json,*.jsonc -ErrorAction Stop).FullName
        [String]$SaltTemplateFile     = (Get-ChildItem -Path "$ConfigSourcePath\*" -Include *.psm1 -ErrorAction Stop).FullName

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   METACONFIG
        #
        #   The MetaConfig is a configfile with info about the actual Salt config
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #  

        [PSObject]$MetaConfigObject = Get-DryFromJson -Path $SaltMetaConfigFile -ErrorAction Stop 
        
        
        #! Gå igjennom fra her
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   The Salt Template
        #
        #   The Salt Template is an incomplete Salt psm1-file. It lacks the specific 
        #   modules and resources to install and load. This is merely because: I could 
        #   put them in the psm1, but Salt, for some reason, does not handle the installation
        #   of them on the local, and target system. So they're in the MetaConfig
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        [String]$SaltTemplate = Get-Content -Path $DscTemplateFile -Raw -ErrorAction Stop

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   DSC_MODULES
        #
        #   Dsc modules are specified in property dsc_modules in the configuration.  
        #   They are automatically added to the target psm1-template, and installed
        #   on the local and remote system
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        If ($MetaConfigObject.dsc_modules) {

            [string]$DscImportModulesString = "# Importing Desired State Modules `n"
            [string]$DscImportResourcesString = "# Importing Desired State Resources `n"
            
            ForEach ($DscModule in $MetaConfigObject.dsc_modules) {
                # Get all property names
                $PropertyNames = ($DscModule | Get-Member -MemberType NoteProperty | Select-Object -Property Name).Name
                
                # Import-Module string ex: Import-Module -Name 'xDnsServer' -RequiredVersion '1.16.0.0'
                # To support any ---version (requiredVersion,minimumversion, maximumversion)
                $DscImportModulesString+="Import-Module "
                ForEach ($PropertyName in $PropertyNames) {
                    $DscImportModulesString+="-$PropertyName '$($DscModule.""$PropertyName"")' "
                }
                $DscImportModulesString+="`n"
                
                # Import-DscConfiguration string ex: Import-DSCResource -Modulename 'xActiveDirectory'
                $DscImportResourcesString+="Import-DscResource -ModuleName '$($DscModule.name)' -ModuleVersion $($DscModule.requiredversion)`n"
    
                ###ImportModules###
                #>
            }
            $DscImportModulesString+="`n"
            $DscImportResourcesString+="`n"

            # Static replacement strings for Import-module '###ImportModules###' and Import-DscResource '###ImportResources###'
            $DscTemplate = $DscTemplate.Replace('###ImportModules###',"$DscImportModulesString")
            $DscTemplate = $DscTemplate.Replace('###ImportResources###',"$DscImportResourcesString")
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   DSC_PARAMS
        #
        #   Parameters are specified in property dsc_params in the configuration.  
        #   All are splattet to the target psm1-dsc-configuration. 
        #   Values may be expressions that resolves the paramater value, a 
        #   string that is ised as is, or a function call. 
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        If ($MetaConfigObject.dsc_params) {

            [HashTable]$ParamsHash
            ForEach ($param in $MetaConfigObject.dsc_params) {

                Switch ($param.value_type) {
                    'expression' {
                        # The variable value is an expression
                        Try {
                            Remove-Variable -name varvalue -ErrorAction Ignore
                            Switch ($param.parameter_type) {
                                'pscredential' {
                                    [pscredential]$varvalue = Invoke-Expression -Command $Param.value
                                    If ( -not ($varvalue -is [pscredential]) ) {
                                        Throw "$($param.Name) is not a pscredential!"
                                    }
                                    ol v "$($param.Name):> user '$($varvalue.username)', password '$($varvalue.password)'"
                                    $ParamsHash += @{ $param.Name = $varvalue }
                                }
                                
                                'array' {
                                    [array]$varvalue = Invoke-Expression -Command $Param.value
                                    If ( -not ($varvalue -is [array]) ) {
                                        Throw "$($param.Name) is not an array!"
                                    }
                                    ForEach ($item in $varvalue) {
                                        ol v "$($param.Name):> '$item' (may be empty If not string)"
                                    }
                                    $ParamsHash += @{ $param.Name = $varvalue }
                                }

                                Default {
                                    # string
                                    [string]$varvalue = Invoke-Expression -Command $Param.value
                                    If ( -not ($varvalue -is [string]) ) {
                                        Throw "$($param.Name) is not a string!"
                                    }
                                    ol v "$($param.Name):> '$varvalue'"
                                    $ParamsHash += @{ $param.Name = $varvalue }
                                }
                            }   
                        }
                        Catch {
                            ol e "Error executing variable expression for: '$($param.name)', expression: '$($param.value)'"
                            $PSCmdlet.ThrowTerminatingError($_)
                        }  
                    }
                    'string' {
                        # The variable value is a plain string
                        Try {
                            Remove-Variable -name varvalue -ErrorAction Ignore
                            
                            [string]$varvalue = $param.Value
                            If ( -not ($varvalue -is [string]) ) {
                                Throw "$($param.Name) is not a string!"
                            }
                            ol v "$($param.Name):> '$varvalue'"
                            $ParamsHash += @{ $param.Name = $varvalue }
                        }
                        Catch {
                            ol e "Error getting string value for: '$($param.name)', string: '$($param.value)'"
                            $PSCmdlet.ThrowTerminatingError($_)
                        }  
                    }
                    'bool' {
                        # The variable value is a boolean
                        Try {
                            Remove-Variable -name varvalue -ErrorAction Ignore
                            
                            [Boolean]$varvalue = $param.Value
                            ol v "$($param.Name):> '$varvalue'"
                            $ParamsHash += @{ $param.Name = $varvalue }
                        }
                        Catch {
                            ol e "Error getting boolean value for: '$($param.name)', value: '$($param.value)'"
                            $PSCmdlet.ThrowTerminatingError($_)
                        }  
                    }
                    'function' {
                        # The variable value is a function
                        Try {
                            Remove-Variable -name varvalue,FunctionParamsHash,FunctionParamsNameArr,FunctionParamsName -ErrorAction Ignore
                            [HashTable]$FunctionParamsHash
                            $FunctionParamsNameArr = @($param.parameters | Get-Member -MemberType NoteProperty | Select-Object -Property Name).Name
                            
                            ForEach ($FunctionParamsName in $FunctionParamsNameArr) {
                                # First, value of $param.parameters."$FunctionParamsName" is now string like '$Resource' and not a variable representing the object $Resource. 
                                # Fix that by invoking the string
                                $param.parameters."$FunctionParamsName" = Invoke-Expression -Command ($param.parameters."$FunctionParamsName") -Erroraction 'Stop'
                                
                                # Add the key value pair to hash, so we can @splat
                                $FunctionParamsHash+= @{ $FunctionParamsName = $param.parameters."$FunctionParamsName" }
                            }
                        
                            Switch ($param.parameter_type) {
                                'pscredential' {
                                    [pscredential]$varvalue = & $param.function @FunctionParamsHash
                                    
                                    If ( -not ($varvalue -is [pscredential]) ) {
                                        Throw "$($param.Name) is not a pscredential!"
                                    }
                                    ol v "$($param.Name):> user '$($varvalue.username)', password '$($varvalue.password)'"
                                    $ParamsHash += @{ $param.Name = $varvalue }
                                }
                                
                                'array' {
                                    [array]$varvalue = & $param.function @FunctionParamsHash
                                    If ( -not ($varvalue -is [array]) ) {
                                        Throw "$($param.Name) is not an array!"
                                    }
                                    ForEach ($item in $varvalue) {
                                        ol v "$($param.Name):> '$item' (may be empty if not string)"
                                    }
                                    $ParamsHash += @{ $param.Name = $varvalue }
                                }

                                Default {
                                    [string]$varvalue = & $param.function @FunctionParamsHash
                                    If ( -not ($varvalue -is [string]) ) {
                                        Throw "$($param.Name) is not a string!"
                                    }
                                    ol v "$($param.Name):> '$varvalue'"
                                    $ParamsHash += @{ $param.Name = $varvalue }
                                }
                            } 
                        }
                        Catch {
                            ol e "Error executing variable expression for: '$($param.name)', expression: '$($param.value)'"
                            $PSCmdlet.ThrowTerminatingError($_)
                        }
                    }
                }
            }

            # ParamsHash to the verbose stream
            ol v "Listing resolved parameters hash below:"
            ol v -hash $ParamsHash
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   DSC_TARGET
        #
        #   The target is by default the $resource IP, but may be some other resource
        #   specified by the dsc_target property. May be an expression that resolves
        #   the target, or a string pointing directly to it
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $DscTarget = $Resource.resolved_network.ip_address

        If ($MetaConfigObject.dsc_target) { 
            $DscTarget = $Null
            Switch ($MetaConfigObject.dsc_target.value_type) {
                'expression' {
                    # The variable value is an expression
                    Try {
                        Remove-Variable -name varvalue -ErrorAction Ignore
                        [string]$varvalue = Invoke-Expression -Command $MetaConfigObject.dsc_target.value
                        If ( -not ($varvalue -is [string]) ) {
                            Throw "$($MetaConfigObject.dsc_target.value) is not a string!"
                        }
                        $DscTarget = $varvalue
                    }
                    Catch {
                        ol e "Error executing dsc_target value expression: $($MetaConfigObject.dsc_target.value)"
                        $PSCmdlet.ThrowTerminatingError($_)
                    }  
                }
                'string' {
                    
                    [string]$varvalue = $MetaConfigObject.dsc_target.value
                    $DscTarget = $varvalue
                }
                'function' {
                    Write-Error "not supported yet. If needed, develop in the DryDSC module" -ErrorAction Stop
                }
            }
        }

        ol -t 6 -arr "The DSC Target is","$DSCTarget"

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   DSC_REPLACEMENTS
        #
        #   Probably not needed, since you can basiclly do everything with variables 
        #   and loops in the DSC
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        If ($MetaConfigObject.dsc_replacements) {

            ForEach ($Replacement in $MetaConfigObject.dsc_replacements) {

                Switch ($Replacement.value_type) {
                    'function' {
                        # If $Replacement has parameters, collect them in hash so we can splat
                        If ($Replacement.parameters) {

                            Remove-Variable -name ReplacementParamsHash -ErrorAction Ignore
                            [HashTable]$ReplacementParamsHash = @{}
                            $ReplacementParamsNameArr = @($Replacement.parameters | 
                                Get-Member -MemberType NoteProperty | 
                                Select-Object -Property Name).Name
                            
                            ForEach ($ReplacementParamsName in $ReplacementParamsNameArr) {
                                # First, value of $Replacement.parameters."$FunctionParamsName" is now string like '$Resource' and not a variable representing the object $Resource. 
                                # Fix that by invoking the string
                                $Replacement.parameters."$ReplacementParamsName" = Invoke-Expression -Command ($Replacement.parameters."$ReplacementParamsName") -Erroraction 'Stop'
                                
                                # Add the key value pair to hash, so we can @splat
                                $ReplacementParamsHash+= @{ $ReplacementParamsName = $Replacement.parameters."$ReplacementParamsName" }
                            }
                        }
                        # Add the replacement pattern to the hash 
                        $ReplacementParamsHash+= @{ 'replacement_pattern'=$Replacement.replacement_pattern }

                        # Then add the template to the hash
                        $ReplacementParamsHash+= @{ 'dsc_template'=$DscTemplate}
                        
                        # Call the function, it will return the template 
                        $DscTemplate = & $Replacement.function @ReplacementParamsHash  
                    }
                }
            }
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   PRE-CREDENTIAL
        #
        #   $Action.credentials.credential1 refers to the alias of the credential used
        #   to deploy the DSC Configuration.
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $DscTargetSystemPRECredentials = Get-DryCredential -Name "$($Action.credentials.credential1)"


        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   DSC MODULES
        #
        #   Ensure modules are installed on the target system and executing host
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        If ($MetaConfigObject.dsc_modules) {

            # Ensure that the local (executing) system has the requires modules
            ol -t 6 -arr 'Trying to install DSC modules on','Local System'
            $MetaConfigObject.dsc_modules | Install-DryDSCModule 
            

            # Ensure that the target system has the requires modules
            $SessionConfig = $Configuration.connections | 
            Where-Object { 
                $_.type -eq 'winrm'
            }
            If ($Null -eq $SessionConfig) {
                ol -t 1 -m "Unable to find 'connection' of type 'winrm' in environment config"
                Throw "Unable to find 'connection' of type 'winrm' in environment config"
            }
            Else {
                $GetDryPSSessionParameters += @{ 'SessionConfig'=$SessionConfig}
            }
            
            $GetDryPSSessionParameters += @{ 'ComputerName'=$DSCTarget }
            $GetDryPSSessionParameters += @{ 'Credential'=$DscTargetSystemPRECredentials }
            $GetDryPSSessionParameters += @{ 'SessionType'='PSSession' }

            $DSCSession = New-DrySession @GetDryPSSessionParameters
            
            ol -t 6 -arr "Trying to install DSC modules on","$DSCTarget" 
            $MetaConfigObject.dsc_modules | Install-DryDSCModule -Session $DSCSession  
            
            ol -t 6 -m 'Done installing DSC modules' -sh
        }

        If ($MetaConfigObject.dsc_sleep_before_seconds) {
            ol -t 6 -arr "Sleep before applying","$($MetaConfigObject.dsc_sleep_before_seconds) seconds"
            Start-DryUtilsSleep -seconds $MetaConfigObject.dsc_sleep_before_seconds
        }

         # Define the mof directory path and the mof, meta.mof and the dsc module target file path
         $MofTargetDir    = Join-Path -Path $ConfigTargetPath -ChildPath 'DSCConfiguration'
         $MofTarget       = Join-Path -Path $MofTargetDir     -ChildPath "$($DSCTarget).mof"
         $MetaMofTarget   = Join-Path -Path $MofTargetDir     -ChildPath "$($DSCTarget).meta.mof"
         $DscModuleTarget = Join-Path -Path $ConfigTargetPath -ChildPath 'dsc.psm1'

        # Create folders that does not exist
        @($ConfigTargetPath,$MofTargetDir).ForEach({
            If (-not (Test-Path -Path $_ -ErrorAction Ignore)) {
                New-Item -Path $_ -ItemType Directory -Confirm:$false -Force | Out-Null
            }
        })
        
        # Delete any dsc module (DSC Configuration) and mofs from previous runs
        @($DscModuleTarget,$MofTarget,$MetaMofTarget).ForEach({
            If (Test-Path -Path $_ -ErrorAction Ignore) {
                Remove-Item -Path $_ -Force -Confirm:$false | Out-Null
            }
        })
        
        # Write the DSC Module $DscModuleTarget
        Out-File -FilePath "$DscModuleTarget" -Encoding ascii -InputObject $DscTemplate
     
         
        # Import the DSC configuration module
        ol -t 6 -arr "Importing module",'PSDesiredStateConfiguration'
        Import-Module -Name PSDesiredStateConfiguration 
        
        ol -t 6 -arr "Importing module","$DscModuleTarget"
        Import-Module -Name "$DscModuleTarget" -Force

        # Create the configuration data
        $ConfigurationData = @{
            AllNodes = @(
                @{
                    NodeName                    = $DscTarget
                    PSDscAllowPlainTextPassword = $True
                    PSDscAllowDomainUser        = $True
                    RebootNodeIfNeeded          = $True
                    ActionAfterReboot           = 'ContinueConfiguration'            
                    ConfigurationMode           = 'ApplyOnly'
                }
            )
        }
        
        # All configurations must be called 'DryDSCConfiguration'. Creates the mof and meta.mof
        ol -t 6 -arr 'Creating DSC mof files in',"$MofTargetDir"
        DryDSCConfiguration -ConfigurationData $ConfigurationData @ParamsHash -Outputpath $MofTargetDir 

        # Create cimsession 
        ol -t 6 -arr 'Creating CIMSession to',"$DscTarget"
        $GetDryCIMSessionParameters = @{
            'Credential'=$DscTargetSystemPRECredentials
            'ComputerName'=$DscTarget
            'SessionType'='CIMSession'
        }
        $SessionConfig = $Configuration.connections | 
        Where-Object { 
            $_.type -eq 'winrm'
        }

        If ($Null -eq $SessionConfig) {
            ol v "Unable to find 'connection' of type 'winrm' in environment config"
            Throw "Unable to find 'connection' of type 'winrm' in environment config"
        }
        Else {
            $GetDryCIMSessionParameters += @{ 'SessionConfig'=$SessionConfig}
        }
        $CimSession = New-DrySession @GetDryCIMSessionParameters
        
        # If the meta.mof exists, apply it
        If (Test-Path -Path $MetaMofTarget -ErrorAction Ignore) {
            ol -t 6 -arr 'Applying meta configuration',"$MetaMofTarget"
            Set-DSCLocalConfigurationManager -Path $MofTargetDir -CimSession $CimSession -Verbose -Force
        }
        
        ol -t 6 -arr 'Publishing configuration to',"$DscTarget"
        Publish-DSCConfiguration -Path $MofTargetDir -CimSession $CimSession -Verbose -Force
            
        ol -t 6 -m "Start DSC Configuration. Wait for it to finish"
        Start-DscConfiguration -UseExisting -CimSession $CimSession -Wait -Verbose -Force
        
        # Remove cim session
        $CimSession | 
        Remove-CimSession -ErrorAction SilentlyContinue 

        # Wait for the winrm interface to come up
        $SessionConfig = $Configuration.connections | 
        Where-Object { 
            $_.type -eq 'winrm'
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   POST-CREDENTIAL
        #
        #   After the DSC has been the deployed, you may need to connect with a different 
        #   credential (for instance when the DSC promotes a Domain Controller). 
        #   $Action.credentials.credential2 may refer to that. If unspecified, credential1 
        #   will be used for the post-deployment connection as well.
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        If ($Action.credentials.credential2) {
            ol -t 6 -arr "Post-Credential","$($Action.credentials.credential2) (credential2 - specific Post-Credential)"
            $DscTargetSystemPOSTCredentials = Get-DryCredential -Name "$($Action.credentials.credential2)"
            If ($MetaConfigObject.dsc_allow_alternating_post_credentials) {
                ol -t 6 -arr "Allowing alternating credentials. Alternating between","'$($Action.credentials.credential1)' and '$($Action.credentials.credential2)'"
                $DscTargetSystemPOSTCredentialsArray = @($DscTargetSystemPRECredentials,$DscTargetSystemPOSTCredentials)
            }
            Else {
                ol -t 6 -arr "Disallowing alternating credentials. Using","'$($Action.credentials.credential2)'"
                $DscTargetSystemPOSTCredentialsArray = @($DscTargetSystemPOSTCredentials)
            }
        }
        Else {
            ol -t 6 -arr "Post-Credential","$($Action.credentials.credential2) (credential1 - same as Pre-Credential)"
            $DscTargetSystemPOSTCredentials = Get-DryCredential -Name "$($Action.credentials.credential1)"
            $DscTargetSystemPOSTCredentialsArray = @($DscTargetSystemPOSTCredentials)
        }
        
        $WaitWinRMInterfaceParams = @{
            'IP'=$DSCTarget
            'Computername'=$Resource.name
            'Credential'=$DscTargetSystemPOSTCredentialsArray
            'SecondsToTry'=300
            'SecondsToWaitBeforeStart'=5
            'SessionConfig'=$SessionConfig
        }
        $WinRMStatus = Wait-DryWinRM @WaitWinRMInterfaceParams
        
        Switch ($WinRMStatus) {
            $False {
                Throw "Failed to Connect to DSC Target: $($DSCTarget))"
            }
            Default {
                # Do nothing
            }  
        }

        ol -t 6 -m "Waiting for Local Configuration Manager (LCM) to finish..."
        $LcmInDesiredState = $false
        
        # By default, I will test the configuration status every 60 seconds until finsihed, but
        # for very large or very small configurations, you may want to increase or decrease it
        [int]$DscTestIntervalSeconds = 60
        If ($MetaConfigObject.dsc_test_interval_seconds) {
            [int]$DscTestIntervalSeconds = $MetaConfigObject.dsc_test_interval_seconds
        }

        # Since you just threw a massive configuration on a poor server, you probably wanna give it 
        # some seconds to finish processing before asking it to test the configuration. By default, 
        # I wait 15 seconds, but you may increase or decrease that for very large or very small configs. 
        [int]$DscTestBeforeSeconds = 15
        If ($MetaConfigObject.dsc_test_before_seconds) {
            [int]$DscTestBeforeSeconds = $MetaConfigObject.dsc_test_before_seconds
        }

        Start-DryUtilsSleep -Seconds $DscTestBeforeSeconds -Message "Sleeping before testing configuration"

        Do {
            $CimSession | 
            Remove-CimSession -ErrorAction Ignore
            $CimSession = New-DrySession @GetDryCIMSessionParameters
            $LcmObject = Test-DSCConfiguration -Detailed -CimSession $CimSession -ErrorAction SilentlyContinue
            If ($LcmObject.InDesiredState) {
                $LcmInDesiredState = $true
                ol -t 6 -m "Local Configuration Manager (LCM) is finished!" -sh
            } 
            Else {
                ol -t 6 -m "Local Configuration Manager (LCM) not in desired state yet"
                # test for instances that are allowed not to be in desired state
                Remove-Variable -Name ResourceInstancesNotInDesiredState -ErrorAction Ignore
                $ResourceInstancesNotInDesiredState = @($LcmObject.ResourcesNotInDesiredState.InstanceName)

                $ResourceInstancesNotInDesiredState.ForEach({
                    # This is sometimes $null, so $_.trim() failes
                    If ($Null -ne $_) {
                        If (($_.Trim()) -ne '') {
                            ol -t 6 -arr 'Resource not in desired state yet',"$_"
                        }
                    }
                })
                
                If (($MetaConfigObject.dsc_allowed_not_in_desired_state).count -gt 0) {
                    [array]$AllowedNotInDesiredState = $MetaConfigObject.dsc_allowed_not_in_desired_state
                    
                    $NotInDesiredStateCount = 0
                    $ResourceInstancesNotInDesiredState.ForEach({
                        If ($AllowedNotInDesiredState -contains $_) {
                            ol i @("Instances allowed to be not in it's desired state","$_")
                            $NotInDesiredStateCount++
                        }
                    })
                    
                    If ($NotInDesiredStateCount -ge $ResourceInstancesNotInDesiredState.Count) {
                        ol w "Some Resources are not in the Desired State, but are allowed not to be according to the configuration. Assuming all is OK and ready to move on "
                        ol i "Assuming LCM is in it's Desired State - moving on" -sh
                        $LcmInDesiredState = $true
                    }
                }
            }

            If (-not ($LcmInDesiredState)) {
                Start-DryUtilsSleep -Seconds $DscTestIntervalSeconds -Message "Sleeping $DscTestIntervalSeconds seconds before re-testing..."
            }

        }
        While (-not $LcmInDesiredState)
        
        $CimSession | 
        Remove-CimSession -ErrorAction Ignore
        
        If ($MetaConfigObject.dsc_restart_after_lcm_finish) {
            # Restart the target system
            Restart-Computer -ComputerName $DSCTarget -Credential $DscTargetSystemPOSTCredentials -Force
 
            [int]$DscWaitForRebootSeconds = 30
            If ($MetaConfigObject.dsc_wait_for_reboot_seconds) {
                [int]$DscWaitForRebootSeconds = $MetaConfigObject.dsc_wait_for_reboot_seconds
            }

            ol i "Waiting $DscWaitForRebootSeconds seconds for the target to restart..."
            Start-DryUtilsSleep -Seconds $DscWaitForRebootSeconds
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   VERIFICATION LOG EVENTS
        #
        #   The property .verification_log_events specifies events that must be found 
        #   in the event log for the configuration to be verified. You must specifiy
        #   which event log to search, and an idenfier, for instance event_id. You 
        #   must also specify how long to wait for the verification events before 
        #   I will fail the action
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $VerificationObject = $MetaConfigObject.verification_log_events

        If ($VerificationObject) {
            ol i "DSC Configuration contains verification log events"
            
            $GetDrySessionParams = @{
                Computername  = $DSCTarget
                Credential    = $DscTargetSystemPOSTCredentials
                SessionConfig = $SessionConfig
                SessionType   = 'PSSession'
            }
            
            $WaitDryForEventParamaters = @{}
            If ($Null -ne $VerificationObject.seconds_to_try) {
                $WaitDryForEventParamaters['SecondsToTry'] = $VerificationObject.seconds_to_try
            }

            If ($Null -ne $VerificationObject.seconds_to_wait_between_tries) {
                $WaitDryForEventParamaters['SecondsToWaitBetweenTries'] = $VerificationObject.seconds_to_wait_between_tries
            }

            If ($Null -ne $VerificationObject.seconds_to_wait_before_start) {
                $WaitDryForEventParamaters['SecondsToWaitBeforeStart'] = $VerificationObject.seconds_to_wait_before_start
            }
            
            If (($VerificationObject.filters).Count -eq 0) {
                Throw "Missing filters in verification_log_events"
            }
            Else {
                $Filters = @()
                $VerificationObject.filters.foreach({
                    $Filter = @{}
                    $_.psobject.properties | 
                    ForEach-Object { 
                        $Filter.Add($_.Name,$_.Value) 
                    }
                    $Filters += $Filter
                })
                $WaitDryForEventParamaters['Filters'] = $Filters
            }

            Try {
                # Add SessionParameters to ParamsHash
                # $TestSession = New-DrySession @GetDrySessionParams
                $WaitDryForEventParamaters.Add('SessionParameters',$GetDrySessionParams)
                Wait-DryUtilsForEvent @WaitDryForEventParamaters
            }
            Catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            Finally {
                # $TestSession | Remove-PSSession -ErrorAction Ignore
            }
        }
        Else {
            ol -t 6 -m "DSC Configuration contains no verification log events - moving on"
        }
    }
    Catch {
        # Testing for non-error-catches
        # This should of course go into config instead
        If ($_.Exception -match "The Active Directory Certificate Services installation is incomplete. To complete the installation, use the request file") {
            ol -t 1 "Ignoring DSC Exception"
        }
        Else {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    Finally {
        Set-Location $Location -ErrorAction SilentlyContinue

        Remove-Module -Name PSDesiredStateConfiguration,DryDSC -ErrorAction Ignore 

        # Remove temporary files
        If ($GLOBAL:dry_var_global_KeepConfigFiles) {
            ol i @('Keeping ConfigFiles in',"$ConfigTargetPath")
        }
        Else {
            ol i @('Removing ConfigFiles from',"$ConfigTargetPath")
            Remove-Item -Path $ConfigTargetPath -Recurse -Force -Confirm:$false
        }

        @(
            'Location',
            'ConfigSourcePath',
            'ConfigOSSourcePath',
            'ConfigTargetPath',
            'MetaConfigObject',
            'DscTemplate',
            'DscImportModulesString',
            'DscImportResourcesString',
            'PropertyNames',
            'VarValue',
            'ParamsHash',
            'FunctionParamsHash',
            'FunctionParamsNameArr',
            'FunctionParamsName',
            'DscTarget',
            'ReplacementParamsHash',
            'ReplacementParamsHash',
            'DscTargetSystemPRECredentials',
            'DscTargetSystemPOSTCredentials',
            'SessionConfig',
            'GetDryPSSessionParameters',
            'DSCSession',
            'MofTargetDir',
            'MofTarget',
            'MetaMofTarget',
            'DscModuleTarget',
            'ConfigurationData',
            'GetDryCIMSessionParameters',
            'CIMSession',
            'DscTargetSystemPOSTCredentialsArray',
            'WaitWinRMInterfaceParams',
            'WinRMStatus',
            'LcmInDesiredState',
            'DscTestIntervalSeconds',
            'DscTestBeforeSeconds',
            'LcmObject',
            'LcmInDesiredState',
            'ResourceInstancesNotInDesiredState',
            'AllowedNotInDesiredState',
            'NotInDesiredStateCount',
            'LcmInDesiredState',
            'DscWaitForRebootSeconds',
            'VerificationObject',
            'GetDrySessionParams',
            'WaitDryForEventParamaters',
            'Filters',
            'Filter'
        ).Foreach({
            Remove-Variable -Name $_ -ErrorAction Ignore
        })
        
        ol i "Action 'dsc.run' is finished" -sh
    }
}