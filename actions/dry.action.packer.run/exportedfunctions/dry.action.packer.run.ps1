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
        $TestedPackerVersion = [Version]"1.8.0"
        Push-Location

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   OPTIONS
        #
        #   Resolve sources, temporary target folders, and other options 
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $GLOBAL:OptionsObject = Resolve-DryActionOptions -Resource $Resource -Action $Action
        $ConfigSourcePath    = $OptionsObject.ConfigSourcePath
        $ConfigTargetPath    = $OptionsObject.ConfigTargetPath
        
        [System.IO.FileInfo]$MetaFile = Get-ChildItem -Path "$ConfigSourcePath\Config.json" -ErrorAction Stop
        [System.IO.FileInfo]$PackerFile = Get-ChildItem -Path "$ConfigSourcePath\*" -Include "*.pkr.hcl" -ErrorAction Stop

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   METACONFIG
        #   The MetaConfig is a configfile with info about the actual Packer config
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
        [PSObject]$MetaConfig = Get-DryFromJson -Path $MetaFile.FullName -ErrorAction Stop
        Set-Variable -Name 'MetaConfig' -Value $MetaConfig -Scope Global -Force

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   PLATFORM
        #   The Metaconfig may supply an expression to resolve the platform, which 
        #   which often is the case if it's not the null-builder, but also for the 
        #   hyperv-builder, which doesn't connect to anything
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        if ($MetaConfig.platform_expression) {
            [PSObject]$Platform = Invoke-Expression $MetaConfig.platform_expression -ErrorAction Stop
            Set-Variable -Name 'Platform' -Value $Platform -Scope Global -Force
            ol i @("Target Platform","$($Platform.name)")
        }
        else {
            $Platform = $null
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
        #   All vars except secrets are put in a *.vars.json Secrets are passed as  
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
        $TargetVarsFile = Join-Path -Path $ConfigTargetPath -ChildPath "$($Resource.Name)-vars.json"
        ol i @('Packers vars file',"$TargetVarsFile")
       
        # Remove files that may exist from a previous run
        If (Test-Path -Path $ConfigTargetPath -ErrorAction Ignore) {
            ol i @('Removing ConfigFiles from',"$ConfigTargetPath")
            Remove-Item -Path $ConfigTargetPath -Recurse -Force -Confirm:$false
        }
        
        # Create the target folder
        If (-not (Test-Path -Path $ConfigTargetPath -ErrorAction Ignore)) {
            New-Item -Path $ConfigTargetPath -ItemType Directory -Confirm:$false -Force | Out-Null
        }
        
        # Loop through files in the layout
        foreach ($File in $MetaConfig.files) {
            # define full source and destination
            $SourceFile = Join-Path -Path $ConfigSourcePath -ChildPath $File.Name
            $TargetFile = Join-Path -Path $ConfigTargetPath -ChildPath $File.Name
            switch ($File.replace) {
                $True {
                    $RawFileContents = Get-Content -Path $SourceFile -Raw -ErrorAction Stop
                    # Replace all replacement patterns, i.e. '###some_pattern###'
                    $ReplacedFileContents = Resolve-DryReplacementPatterns -InputText $RawFileContents -Variables $Variables
                    $ReplacedFileContents | Out-File -FilePath $TargetFile -Encoding Default -Force
                    Remove-Variable -Name RawFileContents,ReplacedFileContents -ErrorAction Ignore
                }
                Default {
                    # just copy
                    Copy-Item -Path $SourceFile -Destination $TargetFile -Confirm:$false -Force
                }
            }
        }

        # Get a hashtable with the names and values only - but only include vars that are not secret, since we're writing these values to a file
        $VariablesHash = ConvertTo-DryHashtable -Variables $Variables -NotSecrets
        
        # Output the tfvars file. Using json, we don't have to create a shady text-parsing-function for this.
        # Use utf8 by default, but allow the configuration to modify that by specifying tfvars_encoding 
        $Encoding = 'ascii'
        if ($MetaConfig.vars_encoding) {
            $Encoding = $MetaConfig.vars_encoding
        }
        $VariablesHash | 
        ConvertTo-Json -Depth 50 -ErrorAction Stop | 
        Out-File -FilePath $TargetVarsFile -Encoding $Encoding -ErrorAction Stop

        # Make sure the tested Packer version or newer is installed and in path.
        # The $TestedPackerVersion is defined in the top of this file. Eventually, as
        # dry.module.pkgmgmt is implemented, this will call a function in that module 
        # instead
        if (Get-Command -CommandType Application -Name 'Packer') { 
            [Version]$Version = ("{0}" -f ((& packer version) -replace "^Packer v"))
            if ($Version -lt $TestedPackerVersion) {
                throw "You need Packer $($TestedPackerVersion.ToString()) or newer installed and in path"
            }
            else {
                ol i "Packer version installed","v$($Version.ToString())"
            }
            $PackerExe = (Get-Command -CommandType Application -Name 'Packer' | 
                Select-Object -Property Source).Source
        } 
        else { 
            throw "You need to have Packer v$TestedPackerVersion (minimum) installed and in path" 
        }

        # Packer Arguments
        [Array]$Arguments = @("-var-file=""$TargetVarsFile""")
        $DisplayArguments = $Arguments
        foreach ($Var in $Variables | Where-Object { $_.secret -eq $true}) {
            $Arguments += "-var"
            $Arguments += "$($Var.Name)=`"$($Var.Value)`""

            $DisplayArguments += "-var"
            $DisplayArguments += "$($Var.Name)=`"**********`""
            
        }
        $ValidateArguments = $Arguments
        $ValidateDisplayArguments = $DisplayArguments
        
        $ValidateArguments += "$($PackerFile.FullName)"
        $ValidateDisplayArguments += "$($PackerFile.FullName)"
        
        # cd to target
        Set-Location -Path $ConfigTargetPath -ErrorAction Stop

        # Packer Validate
        ol i @('Packer Validate',"& $PackerExe validate $ValidateDisplayArguments")
        & $PackerExe validate $ValidateArguments
        if ($LastExitCode -ne 0) {
            Throw "Packer Validate failed: $LastExitCode" 
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   ACTIONPARAMS
        #   When working with a single Action type, for instance during development, 
        #   it is possible to pass a hashtable of extra commmand line paramaters to 
        #   DryDeploy that will be passed to the receiving program, in this case 
        #   Packer.
        #   Params may be switches (like '-no-color') or key value pairs 
        #   (like '-parallelism=2'). The hash table should in these two cases look 
        #   like this: 
        #       $ActionParams = @{
        #            'no-color'    = $null 
        #            'parallelism' = 2
        #       }
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        if ($ActionParams) {
            foreach ($ActionParam in $ActionParams.GetEnumerator()) {
                if ($null -eq $ActionParam.Value) {
                    # Switch
                    $Arguments += "-$($ActionParam.Name)"
                    $DisplayArguments += "-$($ActionParam.Name)"
                }
                else {
                    # Key-Value pair
                    $Arguments += "-$($ActionParam.Name)=$($ActionParam.Value)"
                    $DisplayArguments += "-$($ActionParam.Name)=$($ActionParam.Value)"
                }
            }
        }
        $Arguments += "$($PackerFile.FullName)"
        $DisplayArguments += "$($PackerFile.FullName)"

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   Packer Build
        #   
        #   Build the config
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        ol i @('Packer Build',"& $PackerExe build $DisplayArguments")
        & $PackerExe build $Arguments
        if ($LastExitCode -ne 0) {
            Throw "Packer Build failed: $LastExitCode" 
        }
        
        # & packer apply -auto-approve $Arguments *>&1 | Tee-Object -Variable ApplyResul
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
        Pop-Location

        # Remove temporary files
        If ($GLOBAL:dry_var_global_KeepConfigFiles) {
            ol i @('Keeping ConfigFiles in',"$ConfigTargetPath")
        }
        Else {
            ol i @('Removing ConfigFiles from',"$ConfigTargetPath")
            Remove-Item -Path $ConfigTargetPath -Recurse -Force -Confirm:$false
        }

        @('TestedPackerVersion',
            'OptionsObject',
            'ConfigSourcePath',
            'ConfigTargetPath',
            'MetaFile',
            'PackerFile',
            'MetaConfig',
            'Platform',
            'ResolveVariablesParams',
            'Variables',
            'TargetVarsFile',
            'SourceFile',
            'TargetFile',
            'VariablesHash',
            'Encoding',
            'Version',
            'PackerExe',
            'Arguments',
            'DisplayArguments',
            'ValidateArguments',
            'ValidateDisplayArguments',
            'ActionParams').Foreach({
            Remove-Variable -Name $_ -ErrorAction Ignore
        })
        

        if (Get-Variable -Name "Platform" -Scope Global -ErrorAction Ignore) {
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