using namespace System.Collections.Generic
function dry.action.packer.run {
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
        $TestedPackerVersion = [Version]"1.8.0"
        Push-Location
        $ConfigSourcePath  = $Resolved.ConfigSourcePath
        $ConfigTargetPath  = $Resolved.ConfigTargetPath
        $PackerFilePath    = Join-Path -Path $Resolved.ConfigSourcePath -ChildPath '*'
        $TargetVarsFile    = Join-Path -Path $ConfigTargetPath -ChildPath "$($Action.Resource.Name)-vars.json"
        [System.IO.FileInfo]$PackerFile = Get-ChildItem -Path $PackerFilePath -Include "*.pkr.hcl" -ErrorAction Stop
        [HashTable]$VariablesHash = ConvertTo-DryHashtable -Variables $Resolved.vars -NotSecrets

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   METACONFIG
        #   The MetaConfig is a configfile with info about the actual Packer config
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # 
        [PSObject]$MetaConfig = $Resolved.TypeMetaConfig
        Set-Variable -Name 'MetaConfig' -Value $MetaConfig -Scope Global -Force

        
        ol i @('Packer vars file',"$TargetVarsFile")
       
        # Remove files that may exist from a previous run
        if (Test-Path -Path $ConfigTargetPath -ErrorAction Ignore) {
            ol i @('Removing ConfigFiles from',"$ConfigTargetPath")
            Remove-Item -Path $ConfigTargetPath -Recurse -Force -Confirm:$false
        }
        
        # Create the target folder
        if (-not (Test-Path -Path $ConfigTargetPath -ErrorAction Ignore)) {
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
                    $ReplacedFileContents = Resolve-DryReplacementPatterns -InputText $RawFileContents -Variables $Resolved.vars
                    $ReplacedFileContents | Out-File -FilePath $TargetFile -Encoding default -Force
                    Remove-Variable -Name RawFileContents,ReplacedFileContents -ErrorAction Ignore
                }
                default {
                    # just copy
                    Copy-Item -Path $SourceFile -Destination $TargetFile -Confirm:$false -Force
                }
            }
        }
        
        # Output the vars file. Using json, we don't have to create a shady text-parsing-function for this.
        # Use utf8 by default, but allow the configuration to modify that by specifying vars_encoding 
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
        if (Get-Command -CommandType Application -Name 'packer') { 
            [Version]$Version = ("{0}" -f ((& packer version) -replace "^Packer v"))
            if ($Version -lt $TestedPackerVersion) {
                throw "You need Packer $($TestedPackerVersion.ToString()) or newer installed and in path"
            }
            else {
                ol i "Packer version installed","v$($Version.ToString())"
            }
            $PackerExe = (Get-Command -Name 'packer' | 
                Select-Object -Property Source).Source
        } 
        else { 
            throw "You need to have Packer v$TestedPackerVersion (minimum) installed and in path" 
        }

        # Packer Arguments
        [System.Collections.ArrayList]$Arguments = @("-var-file=""$TargetVarsFile""")
        [System.Collections.ArrayList]$DisplayArguments = $Arguments
        foreach ($Var in $Resolved.vars | Where-Object { $_.secret -eq $true}) {
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
            throw "Packer Validate failed: $LastExitCode" 
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

        # add force
        if ($GLOBAL:dry_var_global_Force) {
            $Arguments.Insert(0,"-force")
            $DisplayArguments.Insert(0,"-force")
            
        }

        # add on-error
        switch ($GLOBAL:dry_var_global_DestroyOnFailedBuild) {
            $true {
                $OnError = 'cleanup'
            }
            default {
                $OnError = 'abort'
            }
        }
        $Arguments.Insert(0,"-on-error=$OnError")
        $DisplayArguments.Insert(0,"-on-error=$OnError")
        
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   Packer Build
        #   
        #   Build the config
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        ol i @('Packer Build',"& $PackerExe build $DisplayArguments")
        # ol i @('Packer Build',"& $PackerExe build $Arguments")
        & $PackerExe build $Arguments
        if ($LastExitCode -ne 0) {
            throw "Packer Build failed: $LastExitCode" 
        }
        
        # & packer apply -auto-approve $Arguments *>&1 | Tee-Object -Variable ApplyResul
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        Pop-Location

        # Remove temporary files
        if ($GLOBAL:dry_var_global_KeepConfigFiles) {
            ol i @('Keeping ConfigFiles in',"$ConfigTargetPath")
        }
        else {
            ol i @('Removing ConfigFiles from',"$ConfigTargetPath")
            Remove-Item -Path $ConfigTargetPath -Recurse -Force -Confirm:$false
        }

        Get-Variable -Scope Script | Remove-Variable -ErrorAction Ignore
        ol i "Action 'packer.run' is finished" -sh
    }
}