function Invoke-DryPackerDeployment {
    [CmdLetBinding()]
    param (

        [Parameter(Mandatory=$true,HelpMessage="Packer file to process")]
        [System.IO.FileInfo]$PackerFile,

        [Parameter(Mandatory=$true,HelpMessage="The configfile is a file which tells which `
        files are needed in the target folder before execution, and which files I need to `
        open for replacement")]
        [System.IO.FileInfo]$ConfigFile,

        [Parameter(Mandatory=$true,HelpMessage="Root directory into which I will create a `
        folder for this job, and delete it afterwards")]
        [System.IO.FileInfo]$WorkingDirectory,

        [Parameter(Mandatory=$true,HelpMessage="The resource object")]
        [psobject]$Resource,

        [Parameter(Mandatory=$true,HelpMessage="I will turn it into a `
        variables file and pass it to packer (parameter '-var-file'). If specified, I will `
        also replace any pattern in files that you specify that I should do replacements in")]
        [System.Collections.Generic.List[PSObject]]$Variables,

        [Parameter(Mandatory=$false,HelpMessage="List of credentials objects")]
        [PSObject]$Credentials
    )

    try {
        # Make sure the tested Packer version or newer is installed and in path
        $TestedPackerVersion = [Version]"1.7.2"
        
        if (Get-Command -CommandType Application -Name Packer) { 
            $PackerExe = Get-Command -CommandType Application -Name packer
            $VersionString = & packer version
            [Version]$Version = ("{0}" -f ($VersionString -replace "^Packer v"))
            if ($Version -lt $TestedPackerVersion) {
                throw "You need Packer $($TestedPackerVersion.ToString()) or newer installed and in path"
            }
            else {
                ol -t 6 -arr "Packer version installed","v$($Version.ToString())"
            }

            $PackerExe = (get-command -CommandType Application -Name Packer | 
                Select-Object -Property Source).Source
        } 
        else { 
            throw "You need to have Packer v$TestedPackerVersion (minimum) installed and in path" 
        }

        # Push current location
        Push-Location

        # Source location. That's where the role's ProvisionPack config files are located
        $SourceLocation = Split-Path -Path $PackerFile

        # Create variables file to pass to packer
        $TargetVarsFile = "$WorkingDirectory\variables.json"
        
        $VariablesHash = @{}
        foreach ($Var in $Variables) {
            $VariablesHash.Add($Var.Name,$Var.Value)
        }

        $VariablesHash | 
        ConvertTo-Json -Depth 3 |
        Out-File -FilePath $TargetVarsFile -Encoding Default -Force

        # Layout 
        $Config = Get-Content -Path $ConfigFile -ErrorAction Stop |
        ConvertFrom-Json -ErrorAction Stop

        # Loop through files in the layout
        foreach ($File in $Config.files) {
            # define full source and destination
            $SourceFile = $SourceLocation + '\' + $File.Name
            $TargetFile = $workingDirectory.FullName + '\' + $File.Name
            
            switch ($File.replace) {
                $true {
                    # Get the contents from file
                    $RawFileContents = Get-Content -Path $SourceFile -Raw -ErrorAction Stop

                    # Replace all replacement patterns, i.e. '###some_pattern###'
                    $ReplacedFileContents = Resolve-DryReplacementPatterns -InputText $RawFileContents -Variables $Variables

                    # Write to destination
                    $ReplacedFileContents | 
                    Out-File -FilePath $TargetFile -Encoding Default -Force
                    Remove-Variable -Name RawFileContents,ReplacedFileContents -ErrorAction Ignore
                }
                default {
                    # just copy
                    Copy-Item -Path $SourceFile -Destination $TargetFile -Confirm:$false
                }
            }
        }

        Set-Location -Path $WorkingDirectory.FullName -ErrorAction Stop
        # Connection Credentials - credential1 is used for the connection 
        $ConnectionCredential = $Credentials."credential1" 
        $ConnectionPasswd = $ConnectionCredential.GetNetworkCredential().Password

        # Accumulate the parameters for packer. $Config.connection is either
        # winrm or ssh
        switch ($Config.connection) {
            'winrm' {
                $ArgumentArray = @(
                    "-var",
                    "`"winrm_username=$($ConnectionCredential.username)`"",
                    "-var",
                    "`"winrm_password=$ConnectionPasswd`"",
                    "-var",
                    "`"winrm_host=$($resource.resolved_network.ip_address)`""
                )
            }
            'ssh' {
                $ArgumentArray = @(
                    "-var",
                    "`"ssh_username=$($ConnectionCredential.username)`"",
                    "-var",
                    "`"ssh_password=$ConnectionPasswd`"",
                    "-var",
                    "`"ssh_host=$($resource.resolved_network.ip_address)`""
                )
            }
            default {
                throw "Unknown connection: '$($Config.Connection)'. Expected 'winrm' or 'ssh'"
            }
        }
                
        foreach ($SecondaryCredential in $Config.Secondary_Credentials) {
            $CredName = $SecondaryCredential.Name
            $CredIndex = $SecondaryCredential.Credentials_Index

            if ($Null -eq $Credentials."credential$CredIndex") {
                ol -t 1 -m "Action is missing it's .credential$CredIndex"
                throw "Action is missing it's .credential$CredIndex"
            }
            $SecCredential = $Credentials."credential$CredIndex" 
            $SecPasswd = $SecCredential.GetNetworkCredential().Password
            $SecUsername = $SecCredential.Username
        
            if ($SecUsername -match "\\") {
                $SecUsername = $SecUsername.split('\')[1]
            }
            $ArgumentArray += @(
                "-var", 
                "`"$($CredName)_username=$SecUsername`"",
                "-var", 
                "`"$($CredName)_password=$SecPasswd`""
            )
        }
        
        $ArgumentArray +=@(
            "-var-file=`"$TargetVarsFile`"",
            "$($PackerFile.FullName)"
        )

        # VALIDATE 
        
        Remove-Variable -Name PackerOutput -Scope Local -ErrorAction Ignore
        try {
            ol -t 6 -m "Running Packer validate..."
            & packer validate $ArgumentArray | Tee-Object -Variable PackerOutput 
            
            # Validate gives no output on success on 1.7.6. Somewhere between 1.7.6 and 1.7.8 it says 'The configuration is valid.'
            $PackerValidated = $false
            if ($LOCAL:PackerOutput) {
                $LOCAL:PackerOutput.foreach({
                    ol i 'Packer validate output',"$_"
                    if ($_ -match 'The configuration is valid') {
                        $PackerValidated = $true
                    }
                })
            }
            else {
                # No output
                $PackerValidated = $true
            } 
            if (-not ($PackerValidated)) {
                throw "Packer validate: Failed"
            }
            else {
                ol i 'Packer validate', 'Success'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)    
        }
        
        # BUILD
        try {
            switch ($GLOBAL:dry_var_global_DestroyOnFailedBuild) {
                $true {
                    $OnError = 'cleanup'
                }
                default {
                    $OnError = 'abort'
                }
            }
            

            Remove-Variable -Name PackerOutput -Scope Local -ErrorAction Ignore
            ol i ('Packer Build',"& packer build -on-error=$OnError $ArgumentArray")
            & packer build -on-error=$OnError $ArgumentArray | Tee-Object -Variable PackerOutput 
            
            # Occurances of every success string must be found in the output
            $PackerSuccessStrings = @("Builds finished\. The artifacts of successful builds are")
            $SuccessCount = 0
            $SuccessTargetCount = $PackerSuccessStrings.Count
            
            $LOCAL:PackerOutput.foreach({
                foreach ($PackerSuccessString in $PackerSuccessStrings) {
                    if ($_ -match $PackerSuccessString) {
                        $SuccessCount++
                        ol -t 0 -m "Match for success string '$PackerSuccessString'"
                    }
                }   
            })

            if ($SuccessCount -eq $SuccessTargetCount) {
                ol -t 6 -arr "Packager Build status","Success"
            }
            elseif ($SuccessCount -gt $SuccessTargetCount) {
                ol -t 6 -arr "Packager Build status","Success"
                ol -t 1 -m "Expected to find only $SuccessTargetCount matches in Packer output, but found $SuccessCount"
            }
            else {
                ol -t 6 -arr "Packager Build status","Failed"
                throw "Packer Build failed"
            }    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        # Remove the password
        Remove-Variable -Name ConnectionPasswd -ErrorAction Ignore
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        # Pop back to the root
        Pop-Location
        # make sure the directory is removed
        Remove-Item -Path $workingDirectory -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
    }
}