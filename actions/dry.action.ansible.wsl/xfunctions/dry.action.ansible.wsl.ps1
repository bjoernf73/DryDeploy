function dry.action.ansible.wsl {
    [CmdletBinding()]  
    param (
        [Parameter(Mandatory,HelpMessage="The resolved action object")]
        [PSObject]$Action,

        [Parameter(Mandatory)]
        [PSObject]$Resolved,

        [Parameter(Mandatory,HelpMessage="The resolved global configuration object")]
        [PSObject]$Configuration,

        [Parameter(HelpMessage="Hash directly from the command line to be 
        added as parameters to the function that iniates the action")]
        [HashTable]$ActionParams
    )
    try {
        # the main.yml of the ansible playbook
        $AnsiblePlaybookPath = $Resolved.WslConfigSourcePath + "/main.yml"
        ol v @('Ansible playbook in wsl',"$AnsiblePlaybookPath")

        # inventory ini file in powershell on windows and the wsl equivalent
        $TargetInventoryFile = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($Action.Resource.Name)-inv.ini"
        $wslTargetInventoryFile = $Resolved.WslConfigTargetPath + "/$($Action.Resource.Name)-inv.ini"
        ol v @('Inventory in wsl',"$wslTargetInventoryFile")

        # remove files that may exist from a previous run
        if (Test-Path -Path $Resolved.ConfigTargetPath -ErrorAction Ignore) {
            Remove-Item -Path $Resolved.ConfigTargetPath -Recurse -Force -Confirm:$false
        }
        
        # create the target folder
        if (-not (Test-Path -Path $Resolved.ConfigTargetPath -ErrorAction Ignore)) {
            New-Item -Path $Resolved.ConfigTargetPath -ItemType Directory -Confirm:$false -Force | Out-Null
        }

        # start creating contents of inventory file
        $InventoryINIContent = @"
# Ansible Inventory file for $($Action.Resource.Name)   
[$($Action.Resource.Name)]
$($Resolved.Target)

[$($Action.Resource.Name):vars]

"@
        # add the variables that are not secrets
        foreach ($Var in $Resolved.vars | Where-Object { $_.secret -eq $false}) {
            $InventoryINIContent += "$($Var.Name)=$($Var.Value)`n"
        }
        #$InventoryINIContent | Out-File -FilePath $TargetInventoryFile -Encoding utf8 -Force -ErrorAction Stop

        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [System.IO.File]::WriteAllLines($TargetInventoryFile, $InventoryINIContent, $Utf8NoBomEncoding)


        ol v @('Ansible Inventory file created at',"$TargetInventoryFile")
        ol v @('Ansible Inventory wsl path',"$wslTargetInventoryFile")
        # display content in verbose output
        Get-Content -Path $TargetInventoryFile -Encoding utf8 | ForEach-Object { ol v $_ }

        # ansible-playbook arguments
        [System.Collections.ArrayList]$Arguments = @("-i", 
            $wslTargetInventoryFile, 
            $AnsiblePlaybookPath, 
            "--extra-vars", 
            "`"ansible_password=$($Resolved.Credentials.credential1.GetNetworkCredential().Password) ansible_become_pass=$($Resolved.Credentials.credential1.GetNetworkCredential().Password)`""
        )

        #  "`"ansible_user=$($Credentials.credential1.username) ansible_password=$($Credentials.credential1.GetNetworkCredential().Password)`"")

        <#
        foreach ($Var in $Resolved.vars | Where-Object { $_.secret -eq $true}) {
            $Arguments += "-var"
            $Arguments += "$($Var.Name)=`"$($Var.Value)`""

            $DisplayArguments += "-var"
            $DisplayArguments += "$($Var.Name)=`"**********`""
        }
        #>
        
        <#
        $ValidateArguments = $Arguments
        $ValidateDisplayArguments = $DisplayArguments
        
        $ValidateArguments += "$($PackerFile.FullName)"
        $ValidateDisplayArguments += "$($PackerFile.FullName)"
        
        # cd to target
        Set-Location -Path $Resolved.ConfigTargetPath -ErrorAction Stop

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
        #   Ansible.
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

       
        #>
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   ansible-playbook
        #   
        #   run the playbook in wsl
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #ol i @('Packer Build',"& $PackerExe build $DisplayArguments")
        # ol i @('Packer Build',"& $PackerExe build $Arguments")
        ol i @('ssh-keyscan(wsl)',"Start-Process wsl -ArgumentList `"-d Ubuntu -- ssh-keyscan -H $($Resolved.Target) >> ~/.ssh/known_hosts`" -NoNewWindow -Wait")
        Start-Process wsl -ArgumentList "-d Ubuntu -- ssh-keyscan -H $($Resolved.Target) >> ~/.ssh/known_hosts" -NoNewWindow -Wait

        ol i @('ansible-playbook(wsl)',"Start-Process wsl -ArgumentList `"-d Ubuntu -- ansible-playbook $Arguments -vvvv`" -NoNewWindow -Wait")
        Start-Process wsl -ArgumentList "-d Ubuntu -- ansible-playbook $Arguments" -NoNewWindow -Wait
        if ($LastExitCode -ne 0) {
            throw "ansible-playbook(wsl) failed: $LastExitCode" 
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        # Remove temporary files
        if ($GLOBAL:dry_var_global_KeepConfigFiles) {
            ol i @('Keeping ConfigFiles in',"$($Resolved.ConfigTargetPath)")
        }
        else {
            ol i @('Removing ConfigFiles from',"$($Resolved.ConfigTargetPath)")
            Remove-Item -Path $Resolved.ConfigTargetPath -Recurse -Force -Confirm:$false
        }

        Get-Variable -Scope Script | Remove-Variable -ErrorAction Ignore -Verbose:$false
        ol i "Action 'ansible.wsl' is finished" -sh
    }
}
        
        
        
   