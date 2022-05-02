Using Namespace System.Collections.Generic
function dry.action.terra.run {
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
        [List[String]]$TerraFiles = @((Get-ChildItem -Path "$ConfigSourcePath\*" -Include *.tf -ErrorAction Stop).FullName)
        if ($MetaFiles.count -eq 1) {
            $MetaFile = $MetaFiles[0]
            ol i @("Meta Configuration File",$MetaFile)
        }
        else {
            throw "Multiple .json and/or .jsonc files in '$ConfigSourcePath' - I was excpecting only one!"
        }

        if ($TerraFiles.count -eq 1) {
            $TerraFile = $TerraFiles[0]
            ol i @("Terraform File",$TerraFile)
        }
        else {
            throw "Multiple .tf files in '$ConfigSourcePath' - I was excpecting only one!"
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   METACONFIG
        #   The MetaConfig is a configfile with info about the actual Terra config
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
        [PSObject]$MetaConfig = Get-DryFromJson -File $MetaFile -ErrorAction Stop
        Set-Variable -Name 'MetaConfig' -Value $MetaConfig -Scope Global -Force

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   PLATFORM
        #   The Metaconfig supplies an expression to resolve the platform
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        if ($MetaConfig.platform_expression) {
            [PSObject]$Platform = Invoke-Expression $MetaConfig.platform_expression -ErrorAction Stop
            Set-Variable -Name 'Platform' -Value $Platform -Scope Global -Force
            ol i @('Target Terraform Platform',"$($Platform.name)")
        }
        else {
            ol i @('Target Terraform Platform','(unspecified)')
        }

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
                New-Variable -Name "Credential$Cred" -Value (Get-DryCredential -Alias $Action.credentials."Credential$Cred" -EnvConfig $($GLOBAL.dry_var_global_EnvConfig).name) -Scope Global
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
        $TargetVarsFile = Join-Path -Path $ConfigTargetPath -ChildPath "$($Resource.Name).auto.tfvars.json"
       
        # Remove files that may exist from a previous run
        If (Test-Path -Path $ConfigTargetPath -ErrorAction Ignore) {
            ol i @('Removing ConfigFiles from',"$ConfigTargetPath")
            Remove-Item -Path $ConfigTargetPath -Recurse -Force -Confirm:$false
        }
        
        # Create the target folder
        If (-not (Test-Path -Path $ConfigTargetPath -ErrorAction Ignore)) {
            New-Item -Path $ConfigTargetPath -ItemType Directory -Confirm:$false -Force | Out-Null
        }
        
        # Copy terraform file to target
        Copy-Item -Path $TerraFile -Destination $ConfigTargetPath -ErrorAction Stop

        # Get a hashtable with the names and values only - but only include vars that are not secret, since we're writing these values to a file
        $VariablesHash = ConvertTo-DryHashtable -Variables $Variables -NotSecrets
        
        # Output the tfvars file. Using json, we don't have to create a shady text-parsing-function for this.
        # Use ascii by default, but allow the configuration to modify that by specifying vars_encoding 
        $Encoding = 'ascii'
        if ($MetaConfig.vars_encoding) {
            $Encoding = $MetaConfig.tfvars_encoding
        }
        $VariablesHash | 
        ConvertTo-Json -Depth 50 -ErrorAction Stop | 
        Out-File -FilePath $TargetVarsFile -Encoding $Encoding -ErrorAction Stop
        
        # cd to target
        Set-Location -Path $ConfigTargetPath -ErrorAction Stop

        # Terraform Init
        & terraform init 
        if ($LastExitCode -ne 0) {
            Throw "Terraform Init failed: $LastExitCode" 
        }
        
        <#
        # *>&1 | Tee-Object -Variable InitResult

        $InitSuccessString = 'Terraform has been successfully initialized!'
        $InitSuccess = $false 
        $InitResult.Foreach({
            if ($_ -match $InitSuccessString) {
                $InitSuccess = $true
            }
        })
        if (-not ($InitSuccess)) {
            Throw "Terraform could not init"
        }
        #>
        
        # Terraform Validate
        & terraform validate
        if ($LastExitCode -ne 0) {
            Throw "Terraform Validate failed: $LastExitCode" 
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
            Throw "Terraform could not validate"
        }
        #> 

        # Terraform Apply
        [Array]$Arguments = @()
        foreach ($Var in $Variables | Where-Object { $_.secret -eq $true}) {
            $Arguments += "-var"
            $Arguments += "$($Var.Name)=`"$($Var.Value)`""
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   ACTIONPARAMS
        #   When working with a single Action type, for instance during development, 
        #   it is possible to pass a hashtable of extra commmand line paramaters to 
        #   DryDeploy that will be passed to the receiving program, in this case 
        #   Terraform.  
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        if ($ActionParams) {
            foreach ($ActionParam in $ActionParams.GetEnumerator()) {
                <#
                    Params may be switches (like '-no-color') or key value pairs (like '-parallelism=2')
                    The hash table should in these two cases look like this: 
                    $ActionParams = @{
                        'no-color'    = $null 
                        'parallelism' = 2
                    }
                #>
                if ($null -eq $ActionParam.Value) {
                    # Switch
                    $Arguments += "-$($ActionParam.Name)"
                }
                else {
                    # Key-Value pair
                    $Arguments += "-$($ActionParam.Name)=$($ActionParam.Value)"
                }
            }
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   Terraform Apply
        #   
        #   Apply the config
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        
        # & terraform apply -auto-approve $Arguments *>&1 | Tee-Object -Variable ApplyResult
        & terraform apply -auto-approve $Arguments
        if ($LastExitCode -ne 0) {
            Throw "Terraform Apply failed: $LastExitCode" 
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
        ol i "Action 'terra.run' is finished" -sh
    }
}