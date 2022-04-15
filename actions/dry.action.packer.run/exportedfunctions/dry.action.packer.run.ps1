Using Namespace System.Collections.Generic
function dry.action.packer.run {
    [CmdletBinding()]  
    param (
        [Parameter(Mandatory,HelpMessage="The resolved action 
        object")]
        [PSObject]
        $Action,

        [Parameter(Mandatory,HelpMessage="The resolved resource 
        object")]
        [PSObject]
        $Resource,

        [Parameter(Mandatory,HelpMessage="The resolved global 
        configuration object")]
        [PSObject]
        $Configuration,

        [Parameter(Mandatory,HelpMessage="ResourceVariables 
        contains resolved variable values from the configurations 
        common_variables and resource_variables combined")]
        [List[PSObject]]
        $ResourceVariables,

        [Parameter(HelpMessage="Hash directly from the command 
        line to be added as parameters to the function that 
        iniates the action")]
        [HashTable]
        $ActionParams
    )
    Try {
        # $Location = Get-Location
        Push-Location
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   OPTIONS
        #
        #   Resolve sources, temporary target folders, and other options 
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $OptionsObject       = Resolve-DryActionOptions -Resource $Resource -Action $Action
        $ConfigSourcePath    = $OptionsObject.ConfigSourcePath
        $ConfigTargetPath    = $OptionsObject.ConfigTargetPath
        
        [List[String]]$MetaFiles = @((Get-ChildItem -Path "$ConfigSourcePath\*" -Include *.json,*.jsonc -ErrorAction Stop).FullName)
        [List[String]]$PackerFiles = @((Get-ChildItem -Path "$ConfigSourcePath\*" -Include *.tf -ErrorAction Stop).FullName)
        if ($MetaFiles.count -eq 1) {
            $MetaFile = $MetaFiles[0]
            ol i @("Meta Configuration File",$MetaFile)
        }
        else {
            throw "Multiple .json and/or .jsonc files in '$ConfigSourcePath' - I was excpecting only one!"
        }

        if ($PackerFiles.count -eq 1) {
            $PackerFile = $PackerFiles[0]
            ol i @("packer File",$PackerFile)
        }
        else {
            throw "Multiple .tf files in '$ConfigSourcePath' - I was excpecting only one!"
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   METACONFIG
        #   The MetaConfig is a configfile with info about the actual Packer config
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
        [PSObject]$MetaConfig = Get-DryCommentedJson -Path $MetaFile -ErrorAction Stop

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   PLATFORM
        #   The Metaconfig supplies an expression to resolve the platform
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        [PSObject]$Platform = Invoke-Expression $MetaConfig.platform_expression -ErrorAction Stop
        Set-Variable -Name 'Platform' -Value $Platform -Scope Global -Force
        ol i @("Target Platform","$($Platform.name)")

         # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   CREDENTIALS
        #
        #   $Action.credentials.credential1 connects to the platform
        #   Other credentials may be used for well, other stuff
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        for ($Cred = 1; $Cred -lt 20; $Cred++) {
            Remove-Variable -Name "Credential$Cred" -Scope Global -ErrorAction Ignore
            if ($Action.credentials."Credential$Cred") {
                New-Variable -Name "Credential$Cred" -Value (Get-DryCredential -Alias $Action.credentials."Credential$Cred" -EnvConfig $GLOBAL:EnvConfigName) -Scope Global
            }
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   Variables
        #   All vars except secrets are put in a main.auto.tfvars together with the 
        #   tf-file and automatically picked up at run time. Secrets are passed as  
        #   command line options 
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        If ($MetaConfig.vars) {
            $ResolveVariablesParams = @{
                Variables     = $MetaConfig.vars
                Configuration = $Configuration
                Resource      = $Resource
                Action        = $Action  
                OutputType    = 'list'
            }
            $Variables = Resolve-DryVariables @ResolveVariablesParams
        }
       
        # Define the vars file path
        $TargetTFvarsFile = Join-Path -Path $ConfigTargetPath -ChildPath "$($Resource.Name).auto.tfvars.json"
       
        # Remove files that may exist from a previous run
        If (Test-Path -Path $ConfigTargetPath -ErrorAction Ignore) {
            ol i @('Removing ConfigFiles from',"$ConfigTargetPath")
            Remove-Item -Path $ConfigTargetPath -Recurse -Force -Confirm:$false
        }
        
        # Create the target folder
        If (-not (Test-Path -Path $ConfigTargetPath -ErrorAction Ignore)) {
            New-Item -Path $ConfigTargetPath -ItemType Directory -Confirm:$false -Force | Out-Null
        }
        
        
        # Copy packer file to target
        Copy-Item -Path $PackerFile -Destination $ConfigTargetPath -ErrorAction Stop

        # write the vars file
        $TargetTFvarsFile 
        foreach ($Var in $Variables) {
             "$($Var.Name) = `"$($Var.Value)`"" | Out-File -FilePath $TargetTFvarsFile -Encoding UTF8 -Append 
        }

        # Get a hashtable with the names and values only - but only include vars that are not secret, since we're writing these values to a file
        $VariablesHash = ConvertTo-DryHashtable -Variables $Variables -NotSecrets
        
        # Output the tfvars file. Using json, we don't have to create a shady text-parsing-function for this.
        # Use utf8 by default, but allow the configuration to modify that by specifying tfvars_encoding 
        $Encoding = 'ascii'
        if ($MetaConfig.tfvars_encoding) {
            $Encoding = $MetaConfig.tfvars_encoding
        }
        $VariablesHash | 
        ConvertTo-Json -Depth 50 -ErrorAction Stop | 
        Out-File -FilePath $TargetTFvarsFile -Encoding $Encoding -ErrorAction Stop
        
        # cd to target
        Set-Location -Path $ConfigTargetPath -ErrorAction Stop

        # packer Init
        & packer init 
        if ($LastExitCode -ne 0) {
            Throw "packer Init failed: $LastExitCode" 
        }
        
        <#
        # *>&1 | Tee-Object -Variable InitResult

        $InitSuccessString = 'packer has been successfully initialized!'
        $InitSuccess = $false 
        $InitResult.Foreach({
            if ($_ -match $InitSuccessString) {
                $InitSuccess = $true
            }
        })
        if (-not ($InitSuccess)) {
            Throw "packer could not init"
        }
        #>
        
        # packer Validate
        & packer validate
        if ($LastExitCode -ne 0) {
            Throw "packer Validate failed: $LastExitCode" 
        }
        <#
        *>&1 | Tee-Object -Variable ValidateResult
        $ValidateSuccessString = 'The configuration is valid'
        $ValidateSuccess = $false
        $ValidateResult.Foreach({
            if ($_ -match $ValidateSuccessString) {
                $ValidateSuccess = $true
            }
        })
        if (-not ($ValidateSuccess)) {
            Throw "packer could not validate"
        }
        #> 

        # packer Apply
        [Array]$Arguments = @()
        foreach ($Var in $Variables | Where-Object { $_.secret -eq $true}) {
            $Arguments += "-var"
            $Arguments += "$($Var.Name)=`"$($Var.Value)`""
        }
        
        # & packer apply -auto-approve $Arguments *>&1 | Tee-Object -Variable ApplyResult
        & packer apply -auto-approve $Arguments
        if ($LastExitCode -ne 0) {
            Throw "Packer Apply failed: $LastExitCode" 
        }
        
        # *>&1 | Tee-Object -Variable ApplyResult
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
        Pop-Location
        #Set-Location $Location -ErrorAction Stop 

        # Remove temporary files
        If ($GLOBAL:KeepConfigFiles) {
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
        

        if (Get-Variable -Name "Platform" -Scope Global) {
            Remove-Variable -Name "Platform" -Scope Global -Force
        }
        for ($Cred = 1; $Cred -lt 20; $Cred++) {
            if (Get-Variable -Name "Credential$Cred" -Scope Global -ErrorAction Ignore) {
                Remove-Variable -Name "Credential$Cred" -Scope Global -Force
            }
            if (Get-Variable -Name "Credential$Cred" -Scope Local -ErrorAction Ignore) {
                Remove-Variable -Name "Credential$Cred" -Scope Local -Force
            }
        }
        ol i "Action 'packer.run' is finished" -sh
    }
}