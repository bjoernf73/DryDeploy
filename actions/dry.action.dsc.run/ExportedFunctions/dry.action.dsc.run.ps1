using Namespace System.Collections.Generic
using Namespace System.Management.Automation
using Namespace System.IO
function dry.action.dsc.run {
    [CmdletBinding()]  
    param (
        [Parameter(Mandatory,HelpMessage="The resolved action object")]
        [PSObject]
        $Action,

        [Parameter(Mandatory)]
        [PSObject]
        $Resolved,

        [Parameter(Mandatory,HelpMessage="The resolved global configuration
        object")]
        [PSObject]
        $Configuration,

        [Parameter(HelpMessage="Hash directly from the command line to be 
        added as parameters to the function that iniates the action")]
        [HashTable]
        $ActionParams
    )
    try {
        $SCRIPT:GlobalProgressPreference = $GLOBAL:ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        Push-Location
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            SourceFile is the top .psm1 file
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        [string]$SourceFilePath = Join-Path -Path $Resolved.ConfigSourcePath -ChildPath '*'
        [FileInfo]$SourceFile   = Get-Item -Path $SourceFilePath -Include "*.psm1" -ErrorAction Stop
        [string]$DSCTargetDir   = $Resolved.ConfigTargetPath
        [string]$TargetFilePath = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($SourceFile.Name)"
        [string]$MofTarget      = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($Resolved.target).mof"
        [string]$MetaMofTarget  = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($Resolved.target).meta.mof"       
        ol i @("The DSC Target is","$($Resolved.target)")

        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
           vars are converted to a hashtable so they can be splatted to the DSC Config
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        [HashTable]$ParamsHash = ConvertTo-DryHashtable -Variables $Resolved.vars

        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
           The Import-DSCResource keyword does not support values from parameters, so
           modules from $Resolved.TypeMetaConfig.dsc_modules must be written to the 
           DSC config at execution time to handle modules and versioning of them dynamic
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        $DSCTemplate = Get-Content -Path $SourceFile -ErrorAction Stop
        if ($Resolved.TypeMetaConfig.dsc_modules) {
            [string]$DscImportModulesString = "# Importing Desired State Modules `n"
            [string]$DscImportResourcesString = "# Importing Desired State Resources `n"
            
            foreach ($DscModule in $Resolved.TypeMetaConfig.dsc_modules) {
                if (-not ($DscModule.requiredVersion)) {
                    throw "Desired State Modules must specify a 'requiredversion' property"
                } 
                # Import-Module string ex: Import-Module -Name 'xDnsServer' -RequiredVersion '1.16.0.0'
                $DscImportModulesString+="Import-Module -Name $($DSCModule.Name) -RequiredVersion $($DSCModule.RequiredVersion)`n"
                $DscImportResourcesString+="Import-DscResource -ModuleName '$($DscModule.name)' -ModuleVersion $($DSCModule.requiredversion)`n"
            }
            # Static replacement strings for Import-module '###ImportModules###' and Import-DscResource '###ImportResources###'
            $DscTemplate = $DscTemplate.Replace('###ImportDSCModules###',"$DscImportModulesString")
            $DscTemplate = $DscTemplate.Replace('###ImportDSCResources###',"$DscImportResourcesString")
        }
        $DSCTemplate | Out-File -FilePath $TargetFilePath -Encoding Default -Force 
        [FileInfo]$TargetFile = Get-Item -Path $TargetFilePath -ErrorAction Stop

       <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
           dsc_modules specifies modules to be installed locally on the execution
           host and on the target system
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        if ($Resolved.TypeMetaConfig.dsc_modules) {
            ol i @('trying to install DSC modules on','Local System')
            $Resolved.TypeMetaConfig.dsc_modules | Install-DryDSCModule 
            $SessionConfig = $Configuration.CoreConfig.connections | 
            Where-Object { 
                $_.type -eq 'winrm'
            }
            if ($null -eq $SessionConfig) {
                throw "Unable to find 'connection' of type 'winrm' in environment config"
            }
            else {
                $GetDryPSSessionParams += @{ SessionConfig = $SessionConfig}
            }
            
            $GetDryPSSessionParams += @{ ComputerName = "$($Resolved.target)" }
            $GetDryPSSessionParams += @{ Credential = $Resolved.Credentials.credential1 }
            $GetDryPSSessionParams += @{ SessionType = 'PSSession' }
            $DSCSession = New-DrySession @GetDryPSSessionParams
            
            ol i @('trying to install DSC modules on',"Target ($($Resolved.target))")
            $Resolved.TypeMetaConfig.dsc_modules | Install-DryDSCModule -Session $DSCSession  
            ol i 'DSC modules sucessfully installed' -sh
        }

        if ($Resolved.TypeMetaConfig.dsc_sleep_before_seconds) {
            ol i @('Sleep before applying',"$($Resolved.TypeMetaConfig.dsc_sleep_before_seconds) seconds")
            Start-DryUtilsSleep -seconds $Resolved.TypeMetaConfig.dsc_sleep_before_seconds
        }
        
        # Delete any *.mof and *.meta.mof from previous runs
        if (Test-Path -Path $MofTarget -ErrorAction Ignore) {Remove-Item -Path $MofTarget -Force -Confirm:$false | Out-Null}
        if (Test-Path -Path $MetaMofTarget -ErrorAction Ignore) {Remove-Item -Path $MetaMofTarget -Force -Confirm:$false | Out-Null}

        Import-Module -Name PSDesiredStateConfiguration -Verbose:$false -Force
        
        ol i @('Importing DSC configuration',"$($TargetFile.FullName)")
        Import-Module -Name "$($TargetFile.FullName)" -Force -ErrorAction Stop

        # Create the configuration data
        $ConfigurationData = @{
            AllNodes = @(
                @{
                    NodeName                    = $Resolved.target
                    PSDscAllowPlainTextPassword = $true
                    PSDscAllowDomainUser        = $true
                    RebootNodeifNeeded          = $true
                    ActionAfterReboot           = 'ContinueConfiguration'            
                    ConfigurationMode           = 'ApplyOnly'
                }
            )
        }
        
        # All configurations must be called 'DryDSCConfiguration'. Creates the mof and meta.mof
        ol i @('Creating DSC mof files in',"$DSCTargetDir")
        # configure the LCM  
        Set-Location -Path $DSCTargetDir -ErrorAction Stop

        # Get the name of the configuration & create *.meta.mof and *.mof
        [string]$DSCConfig = (Get-Command -module $TargetFile.BaseName | Where-Object { $_.CommandType -eq 'Configuration' }).Name
        & $DSCConfig -ConfigurationData $ConfigurationData @ParamsHash -OutputPath $DSCTargetDir

        ol i @('Establish CIMSession to',"$($Resolved.target)")
        $GetDryCIMSessionParams = @{
            Credential    = $Resolved.Credentials.credential1
            ComputerName  = $Resolved.target
            SessionConfig = $SessionConfig
            SessionType   = 'CIMSession'
        }
        $CimSession = New-DrySession @GetDryCIMSessionParams
        
        if (Test-Path -Path $MetaMofTarget) {
            Set-DSCLocalConfigurationManager -Path $DSCTargetDir -CimSession $CimSession -Verbose -Force
        }
        
        ol i @('Publishing configuration to',"$($Resolved.target)")
        Publish-DSCConfiguration -Path $DSCTargetDir -CimSession $CimSession -Verbose -Force
            
        ol i 'Starting DSC Configuration' -sh
        Start-DscConfiguration -UseExisting -CimSession $CimSession -Wait -Verbose -Force
        
        # Remove cim session
        $CimSession | Remove-CimSession -ErrorAction SilentlyContinue 

        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            Since you just threw a massive configuration on a poor server, you probably 
            wanna give it some seconds to finish processing before asking it to test the 
            configuration. By default, I wait 15 seconds, but you may increase or decrease
            that for very large or very small configs. 
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        [int]$DscTestBeforeSeconds = 15
        if ($Resolved.TypeMetaConfig.dsc_test_before_seconds) {
            [int]$DscTestBeforeSeconds = $Resolved.TypeMetaConfig.dsc_test_before_seconds
        }
        Start-DryUtilsSleep -Seconds $DscTestBeforeSeconds -Message "Sleeping before testing configuration"


        if (($Action.credentials.credential1 -ne $Action.credentials.credential2) -and ($null -ne $Action.credentials.credential2)) {
            # alternating credentials
            $DscTargetSystemPOSTCredentialsArray = @($Resolved.Credentials.credential1,$Resolved.Credentials.credential2)
        }
        else {
            $DscTargetSystemPOSTCredentialsArray = @($Resolved.Credentials.credential1)
        }
        
        $SessionConfig = $Configuration.CoreConfig.connections | Where-Object { 
            $_.type -eq 'winrm'
        }

        $WaitWinRMInterfaceParams = @{
            IP                       = "$($Resolved.target)"
            Computername             = $Action.Resource.name
            Credential               = $DscTargetSystemPOSTCredentialsArray
            SecondsToTry             = 300
            SecondsToWaitBeforeStart = 5
            SessionConfig            = $SessionConfig
        }
        $WinRMStatus = Wait-DryWinRM @WaitWinRMInterfaceParams
        
        switch ($WinRMStatus) {
            $false {
                throw "Failed to Connect to DSC Target: $($Resolved.target))"
            }
            default {
                # Do nothing
            }  
        }

        ol i "Waiting for LCM to finish..." -sh
        $LcmInDesiredState = $false
        
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
           By default, I will test the configuration status every 60 seconds until 
           finsihed, but for very large or very small configurations, you may want to 
           increase or decrease it
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>

        
        [int]$DscTestIntervalSeconds = 60
        if ($Resolved.TypeMetaConfig.dsc_test_interval_seconds) {
            [int]$DscTestIntervalSeconds = $Resolved.TypeMetaConfig.dsc_test_interval_seconds
        }

        do {
            $CimSession | Remove-CimSession -ErrorAction Ignore
            $CimSession = New-DrySession @GetDryCIMSessionParams
            $LcmObject = Test-DSCConfiguration -Detailed -CimSession $CimSession -ErrorAction SilentlyContinue
            if ($LcmObject.InDesiredState) {
                $LcmInDesiredState = $true
                ol i @('LCM status','in desired state')
            } 
            else {
                ol i @('LCM status','not in desired state (yet)')
                # test for instances that are allowed not to be in desired state
                $ResourceInstancesNotInDesiredState = $null
                $ResourceInstancesNotInDesiredState = @($LcmObject.ResourcesNotInDesiredState.InstanceName)

                $ResourceInstancesNotInDesiredState.foreach({
                    # This is sometimes $null, so $_.trim() failes
                    if ($null -ne $_) {
                        if (($_.Trim()) -ne '') {
                            ol i @('DSC Resource not in desired state yet',"$_")
                        }
                    }
                })
                
                if (($Resolved.TypeMetaConfig.dsc_allowed_not_in_desired_state).count -gt 0) {
                    [array]$AllowedNotInDesiredState = $Resolved.TypeMetaConfig.dsc_allowed_not_in_desired_state
                    
                    $NotInDesiredStateCount = 0
                    $ResourceInstancesNotInDesiredState.foreach({
                        if ($AllowedNotInDesiredState -contains $_) {
                            ol d @("Instances allowed to not be in it's desired state","$_")
                            $NotInDesiredStateCount++
                        }
                    })
                    
                    if ($NotInDesiredStateCount -ge $ResourceInstancesNotInDesiredState.Count) {
                        ol w "Some Resources are not in the Desired State, but are allowed not to be according to the configuration. Assuming all is OK and ready to move on "
                        ol i "Assuming LCM is in it's Desired State - moving on" -sh
                        $LcmInDesiredState = $true
                    }
                }
            }

            if (-not ($LcmInDesiredState)) {
                Start-DryUtilsSleep -Seconds $DscTestIntervalSeconds -Message "Sleeping $DscTestIntervalSeconds seconds before retesting..."
            }

        }
        while (-not $LcmInDesiredState)
        $CimSession | Remove-CimSession -ErrorAction Ignore

        if (($Action.credentials.credential1 -ne $Action.credentials.credential2) -and ($null -ne $Action.credentials.credential2)) {
            # alternating credentials
            $DscTargetSystemPOSTCredentialsArray = @($Resolved.Credentials.credential1,$Resolved.Credentials.credential2)
        }
        else {
            $DscTargetSystemPOSTCredentialsArray = @($Resolved.Credentials.credential1)
        }
        
        $SessionConfig = $Configuration.CoreConfig.connections | Where-Object { 
            $_.type -eq 'winrm'
        }
        if ($Resolved.TypeMetaConfig.dsc_restart_after_lcm_finish) {
            # Restart the target system
            Restart-Computer -ComputerName $Resolved.target -Credential $DscTargetSystemPOSTCredentialsArray -Force
 
            [int]$DscWaitForRebootSeconds = 30
            if ($Resolved.TypeMetaConfig.dsc_wait_for_reboot_seconds) {
                [int]$DscWaitForRebootSeconds = $Resolved.TypeMetaConfig.dsc_wait_for_reboot_seconds
            }

            ol i @('Waiting for the target to restart',"$DscWaitForRebootSeconds seconds" )
            Start-DryUtilsSleep -Seconds $DscWaitForRebootSeconds
        }

        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            Verification Log Events
        
            The property .dsc_verification_log_events specifies events that must be found in 
            the event log for the configuration to be verified. You must specifiy which 
            event log to search, and an idenfier, for instance event_id. You must also 
            specify how long to wait for the verification events before I will fail the 
            action
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        $VerificationObject = $Resolved.TypeMetaConfig.dsc_verification_log_events

        if ($Resolved.TypeMetaConfig.dsc_verification_log_events) {
            ol i @('DSC verification log events defined','Yes')
            $GetDrySessionParams = @{
                Computername  = $($Resolved.target)
                Credential    = $DscTargetSystemPOSTCredentialsArray
                SessionConfig = $SessionConfig
                SessionType   = 'PSSession'
            }
            
            $WaitDryForEventParamaters = @{}
            if ($null -ne $VerificationObject.seconds_to_try) {
                $WaitDryForEventParamaters['SecondsTotry'] = $VerificationObject.seconds_to_try
            }

            if ($null -ne $VerificationObject.seconds_to_wait_between_tries) {
                $WaitDryForEventParamaters['SecondsToWaitBetweenTries'] = $VerificationObject.seconds_to_wait_between_tries
            }

            if ($null -ne $VerificationObject.seconds_to_wait_before_start) {
                $WaitDryForEventParamaters['SecondsToWaitBeforeStart'] = $VerificationObject.seconds_to_wait_before_start
            }
            
            if (($VerificationObject.filters).Count -eq 0) {
                throw "Missing filters in verification_log_events"
            }
            else {
                $Filters = @()
                $VerificationObject.filters.foreach({
                    $Filter = @{}
                    $_.psobject.properties | 
                    foreach-Object { 
                        $Filter.Add($_.Name,$_.Value) 
                    }
                    $Filters += $Filter
                })
                $WaitDryForEventParamaters['Filters'] = $Filters
            }

            try {
                # Add SessionParameters to ParamsHash
                # $TestSession = New-DrySession @GetDrySessionParams
                $WaitDryForEventParamaters.Add('SessionParameters',$GetDrySessionParams)
                Wait-DryUtilsForEvent @WaitDryForEventParamaters
            }
            catch {
                $PSCmdlet.throwTerminatingError($_)
            }
            finally {
                # $TestSession | Remove-PSSession -ErrorAction Ignore
            }
        }
        else {
            ol i @('DSC verification log events','No')
        }
    }
    catch {
        # Testing for non-error-catches
        # This should of course go into config instead
        if ($_.Exception -match "The Active Directory Certificate Services installation is incomplete. To complete the installation, use the request file") {
            ol w "Ignoring DSC Exception"
        }
        else {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    finally {
        $ProgressPreference = $SCRIPT:GlobalProgressPreference
        Pop-Location
        Remove-Module -Name PSDesiredStateConfiguration,dry.action.dsc.run -ErrorAction Ignore 

        if ($GLOBAL:dry_var_global_KeepConfigFiles) {
            ol i @('Keeping ConfigFiles in',"$DSCTargetDir")
        }
        else {
            ol i @('Removing ConfigFiles from',"$DSCTargetDir")
            Remove-Item -Path $DSCTargetDir -Recurse -Force -Confirm:$false
        }
        
        @(Get-Variable -Scope Script).foreach({
            $_ | Remove-Variable -ErrorAction Ignore
        })
        ol i "Action 'dsc.run' is finished" -sh
    }
}