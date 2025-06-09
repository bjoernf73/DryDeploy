function dry.action.ansible.wsl{
    [CmdletBinding()]  
    param(
        [Parameter(Mandatory,HelpMessage="The resolved action object")]
        [PSObject]$Action,

        [Parameter(Mandatory)]
        [PSObject]$Resolved,

        [Parameter(Mandatory,HelpMessage="The resolved global configuration object")]
        [PSObject]$Configuration,

        [Parameter(HelpMessage="From dd's -ActionParams, a hash that will be passed on to the configuration program")]
        [hashtable]$ActionParams
    )
    try{
        # the main.yml of the ansible playbook
        $AnsiblePlaybookPath = $Resolved.WslConfigSourcePath + "/main.yml"

        # inventory ini file in powershell on windows and the wsl equivalent
        $TargetInventoryFile = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($Action.Resource.Name)-inv.ini"
        $wslTargetInventoryFile = $Resolved.WslConfigTargetPath + "/$($Action.Resource.Name)-inv.ini"
        
        # inventory ini file in powershell on windows and the wsl equivalent
        $AnsibleLogFile = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($Action.Resource.Name)-ansible.log"
        $wslAnsibleLogFile = $Resolved.WslConfigTargetPath + "/$($Action.Resource.Name)-ansible.log"
        
        # remove files that may exist from a previous run
        if(Test-Path -Path $Resolved.ConfigTargetPath -ErrorAction Ignore){
            Remove-Item -Path $Resolved.ConfigTargetPath -Recurse -Force -Confirm:$false
        }
        
        # create the target folder
        if(-not (Test-Path -Path $Resolved.ConfigTargetPath -ErrorAction Ignore)){
            New-Item -Path $Resolved.ConfigTargetPath -ItemType Directory -Confirm:$false -Force | Out-Null
        }

        # output to screen 
        ol i @('Ansible playbook in wsl',"$AnsiblePlaybookPath")
        ol i @('Inventory in wsl',"$wslTargetInventoryFile")
        ol i @('log in wsl',"$wslAnsibleLogFile")

        # start creating contents of inventory file
        $InventoryINIContent = @"
# Ansible Inventory file for $($Action.Resource.Name)   
[$($Action.Resource.Name)]
$($Resolved.Target)

[$($Action.Resource.Name):vars]

"@
        # variables that are not secrets are written to the inventory file
        foreach($var in $Resolved.vars | Where-Object{ $_.secret -eq $false}){
            $InventoryINIContent += "$($var.Name)=$($var.Value)`n"
        }
    
        # write the inventory file using UTF8 without BOM
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [system.io.file]::WriteAllLines($TargetInventoryFile, $InventoryINIContent, $Utf8NoBomEncoding)

        # output paths to screen
        ol v @('Ansible Inventory file created at',"$TargetInventoryFile")
        ol v @('Ansible Inventory wsl path',"$wslTargetInventoryFile")

        # ansible-playbook arguments
        [system.collections.arraylist]$Arguments = @(
            "-i", 
            $wslTargetInventoryFile, 
            $AnsiblePlaybookPath,
            "--extra-vars", 
            "`"ansible_password=$($Resolved.Credentials.credential1.GetNetworkCredential().Password) ansible_become_pass=$($Resolved.Credentials.credential1.GetNetworkCredential().Password)`""
        )
       
        # add target to known_hosts
        ol i "Add the target [$($Action.Resource.Name) ($($Resolved.Target))] to known_hosts in wsl" -sh
        ol i @('command',"Start-Process 'wsl' -ArgumentList `"-d Ubuntu -- ssh-keyscan -H $($Resolved.Target) >> ~/.ssh/known_hosts`" -NoNewWindow -Wait")
        Start-Process 'wsl' -ArgumentList "-d Ubuntu -- ssh-keyscan -H $($Resolved.Target) >> ~/.ssh/known_hosts" -NoNewWindow -Wait

        # run the playbook
        ol i "Run the ansible-playbook in wsl" -sh
        ol i @('command',"Start-Process 'wsl' -ArgumentList `"-d Ubuntu -- export ANSIBLE_LOG_PATH=$wslAnsibleLogFile; ansible-playbook $Arguments -vvvv`" -NoNewWindow -Wait")
        Start-Process 'wsl' -ArgumentList "-d Ubuntu -- export ANSIBLE_LOG_PATH=$wslAnsibleLogFile; ansible-playbook $Arguments" -NoNewWindow -Wait

        # test if wsl ran successfully
        if($LASTEXITCODE -ne 0){
            throw "wsl failed to run ansible-playbook: $LASTEXITCODE" 
        }
        
        # test if ansible ran successfully. If so, we should have a log file with a PLAY RECAP
        if(Test-Path -Path $AnsibleLogFile -ErrorAction Ignore){
            ol i @('Ansible log file found at',"$AnsibleLogFile")

            $PlayRecapObj=[pscustomobject]@{
                ok=$null
                changed=$null
                unreachable=$null
                failed=$null
                skipped=$null
                rescued=$null
                ignored=$null
            }

            # find the PLAY RECAP, match values using pattern, and update the PlayRecapObj
            $Pattern = "(ok|changed|unreachable|failed|skipped|rescued|ignored)=(\d+)\s"
            $PlayRecap = ((Get-Content -Path $AnsibleLogFile -Encoding utf8 | Select-String -Pattern "PLAY\sRECAP\s\*\*" -Context 0, 2) -split "`n")[-1]
            $MatchResults = [regex]::Matches($PlayRecap,$Pattern)
            if($MatchResults.Count -lt 7){
                $DoNotDeleteAnsibleLogFile = $true
                throw "No PLAY RECAP found in Ansible log file: $AnsibleLogFile"
            }
            foreach($match in $MatchResults) {
                $PlayRecapObj."$($match.Groups[1].Value)" = [int]$match.Groups[2].Value
            }

            # the failed and unreachable count determines if we throw an error or not.
            if($PlayRecapObj.failed -gt 0){
                $DoNotDeleteAnsibleLogFile = $true
                throw "One or more Ansible Plays failed, see log file: $AnsibleLogFile"
            }
            elseif($PlayRecapObj.unreachable -gt 0){
                $DoNotDeleteAnsibleLogFile = $true
                throw "One or more Ansible target were unreachable, see log file: $AnsibleLogFile"
            }
            elseif($null -eq $PlayRecapObj.ok -or
                   $null -eq $PlayRecapObj.changed -or
                   $null -eq $PlayRecapObj.unreachable -or
                   $null -eq $PlayRecapObj.failed -or
                   $null -eq $PlayRecapObj.skipped -or
                   $null -eq $PlayRecapObj.rescued -or
                   $null -eq $PlayRecapObj.ignored){
                $DoNotDeleteAnsibleLogFile = $true
                throw "No Ansible plays were run, see log file: $AnsibleLogFile"
            }
            else{
                ol i 'Ansible plays succeeded - results below' -sh
                ol i -MsgObj $PlayRecapObj
            }
        }
        else{
            throw "Ansible log file not found: $AnsibleLogFile"
        }
    }
    catch{
        # if anything throws, keeep the ansible log file
        $DoNotDeleteAnsibleLogFile = $true
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
        # Remove temporary files
        if($GLOBAL:dry_var_global_KeepConfigFiles){
            ol i @('Keeping ConfigFiles in',"$($Resolved.ConfigTargetPath)")
        }
        elseif($true -eq $DoNotDeleteAnsibleLogFile){
            ol i @('Keeping ConfigFiles in',"$($Resolved.ConfigTargetPath)")
        }
        else{
            ol i @('Removing ConfigFiles from',"$($Resolved.ConfigTargetPath)")
            Remove-Item -Path $Resolved.ConfigTargetPath -Recurse -Force -Confirm:$false
        }
        Get-Variable -Scope Script | Remove-Variable -ErrorAction Ignore -Verbose:$false
        ol i "Action 'ansible.wsl' is finished" -sh
    }
}