Using Module dry.module.ad
# Using Module ActiveDirectory
# Using Module GroupPolicy
Function dry.action.ad.import {
    [CmdletBinding()]  
    Param (
        [Parameter(Mandatory,HelpMessage="The resolved action object")]
        [PSObject]$Action,

        [Parameter(Mandatory,HelpMessage="The resolved resource object")]
        [PSObject]$Resource,

        [Parameter(Mandatory,HelpMessage="The resolved environment configuration object")]
        [PSObject]$Configuration,

        [Parameter(Mandatory,HelpMessage="ResourceVariables contains resolved 
        variable values from the configurations common_variables and resource_variables combined")]
        [System.Collections.Generic.List[PSObject]]$ResourceVariables,

        [Parameter(HelpMessage="Hash directly from the command 
        line to be added as parameters to the function that iniates the action")]
        [HashTable]$ActionParams
    )

    Try {
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

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   COPY
        #
        #   Copies files from the Role's source to temporary dir.  
        #   May also copy from the OS-specific directory, if specified in Config.json
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $CopyDryActionConfigurationsParams = @{
            'ConfigTargetPath'=$ConfigTargetPath
        }
        
        If (($Null -ne $ConfigSourcePath) -and 
            ($ConfigSourcePath -ne '')) {
            $CopyDryActionConfigurationsParams += @{
                'ConfigSourcePath'=$ConfigSourcePath
            }
        }

        If (($Null -ne $ConfigOSSourcePath) -and 
            ($ConfigOSSourcePath -ne '')) {
            $CopyDryActionConfigurationsParams += @{
                'ConfigOSSourcePath'=$ConfigOSSourcePath
            }
        }
        Copy-DryActionConfigurations @CopyDryActionConfigurationsParams
        
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #  Get Credential 
        # 
        #  The ad.import action uses the first credential, 'credential1', to remote into
        #  remote into a Domain Controller. If that option is unavailable, it will execute
        #  locally with the executing users permissions
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $CredentialAlias = $Action.credentials.credential1
        If ($Null -eq $CredentialAlias) {
            throw "The action 'ad.import' does not contain a credential alias 'credential1' - it should."
        }
        Else {
            ol i @('Action ad.import uses Credential Alias',"$CredentialAlias (credential1)")
        }
        $Credential = Get-DryCredential -Alias $CredentialAlias -EnvConfig $($GLOBAL.dry_var_global_EnvConfig).name

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #  Execution Type 
        # 
        #  In a Greenfield deployment, this is running an a computer outside the domain
        #  and we must remote into a domain controller to execute each configuration
        #  action. However, if this is running on a domain member in that domain, we
        #  assume that the config  may run locally. The DryAD module supports both 
        #  'Local' and 'Remote' execution. The Get-DryAdExecutionType query function
        #  tests if the prerequisites for a Local execution is there
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        Enum ExecutionType { Local; Remote }        
        [ExecutionType]$ExecutionType = Get-DryAdExecutionType -Configuration $Configuration
        ol 6 'Execution Type',$ExecutionType

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   Resolve Active Directory Connection Point
        #
        #   ad.import will target a domain controller on the site the resource belongs to
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $GetDryADConnectionPointParams = @{
            Resource      = $Resource 
            Configuration = $Configuration 
            ExecutionType = $ExecutionType
        }
        If ($ExecutionType -eq 'Remote') {
            $GetDryADConnectionPointParams += @{
                Credential    = $Credential
            }
        }
        
        $ActiveDirectoryConnectionPoint = Get-DryADConnectionPoint @GetDryADConnectionPointParams
        ol 6 "Connection Point (Domain Controller)",$ActiveDirectoryConnectionPoint
        
        # Wait for the winrm interface to come up
        If ($ExecutionType -eq 'Remote') {
            $SessionConfig = $Configuration.connections | Where-Object { 
                $_.type -eq 'winrm'
            }

            $WaitWinRMParams             = @{
                IP                       = $ActiveDirectoryConnectionPoint
                Computername             = $Resource.name
                Credential               = $Credential
                SecondsToTry             = 1800
                SecondsToWaitBeforeStart = 2
                SessionConfig            = $SessionConfig
            }
            $WinRMStatus = Wait-DryWinRM @WaitWinRMParams
            Switch ($WinRMStatus) {
                $False {
                    ol i @("Failed to connected to","$ActiveDirectoryConnectionPoint")
                    Throw "Failed to Connect to: $ActiveDirectoryConnectionPoint"
                }
                $True {
                    ol i @("Connected to","$ActiveDirectoryConnectionPoint")
                }  
            }
            
            # Create session to run the configuration in
            $ConfADSessionParameters += @{
                SessionType  = 'PSSession'
                ComputerName = $ActiveDirectoryConnectionPoint
                Credential   = $Credential
            }
    
            If ($Null -ne $SessionConfig) {
                $ConfADSessionParameters += @{'SessionConfig'=$SessionConfig}
            }
            Try {
                ol i "Establishing PSSession to","$ActiveDirectoryConnectionPoint"
                $PSSession = New-DrySession @ConfADSessionParameters
                ol i "PSSession successfully established"
            }
            Catch {
                ol e @('Failed to establish PSSession to',"$ActiveDirectoryConnectionPoint")
                $PSCmdLet.ThrowTerminatingError($_)
            }
        }
        
        $SetDryADConfigurationParams = @{
            Variables         = $ResourceVariables
            ConfigurationPath = $ConfigTargetPath
            ComputerName      = $Resource.name
            ADSite            = $Resource.network.site
            DryDeploy         = $True
        }
        If ($ExecutionType -eq 'Remote') {
            $SetDryADConfigurationParams += @{
                PSSession = $PSSession
            }
        }
        else {
            $SetDryADConfigurationParams += @{
                DomainController = $ActiveDirectoryConnectionPoint
            }
        }

        If ($ActionParams) {
            $SetDryADConfigurationParams+=$ActionParams
        }
        ol d "Calling 'Import-DryADConfiguration' with the following splat"
        ol d -hash $SetDryADConfigurationParams
        Import-DryADConfiguration @SetDryADConfigurationParams
        $PSSession | Remove-PSSession -ErrorAction Continue
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
        @('ActiveDirectory','GroupPolicy','GPOManagement','RegistryPolicyParser','dry.module.ad'
        ).ForEach({
            Remove-Module -Name $_ -ErrorAction 'Ignore' -Verbose:$False |
            Out-Null
        })

        If ($GLOBAL:dry_var_global_KeepConfigFiles) {
            ol 1 "Keeping ConfigFiles (-KeepConfigFiles was passed) in '$ConfigTargetPath'"
        }
        Else {
            Remove-Item -Path $ConfigTargetPath -Recurse -Force -Confirm:$False
        }
        ol 6 "Action 'ad.import' is finished" -sh
    }
}