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
        # Connection type can be ssh or winrm, defaults to ssh
        $AnsibleConnectionType = 'ssh'
        if($Resolved.TypeMetaConfig.connection -notin 'psrp', 'winrm', 'ssh', $null){
            throw "Unknown connection type: $($Resolved.TypeMetaConfig.connection). Expected 'ssh', 'winrm' or 'psrp'."
        }
        if($null -ne $Resolved.TypeMetaConfig.connection){
            $AnsibleConnectionType = $Resolved.TypeMetaConfig.connection
        }
        ol i @('Ansible connection type',$AnsibleConnectionType)
        
        # Authentication type can be password or key, defaults to password
        $AnsibleAuthenticationType = 'password'
        if($Resolved.TypeMetaConfig.authentication -notin 'password', 'key', $null){
            throw "Unknown authentication type: $($Resolved.TypeMetaConfig.authentication). Expected 'password' or 'key'."
        }
        if($null -ne $Resolved.TypeMetaConfig.authentication){
            $AnsibleAuthenticationType = $Resolved.TypeMetaConfig.authentication
        }
        ol i @('Ansible authentication type',$AnsibleAuthenticationType)

        # supported platforms are Win32NT and Unix. $GLOBAL:dry_var_global_Platform.Platform contains the platform information
        <#
            Name                           Value
            ----                           -----
            Separator                      :
            Slash                          /
            Home                           /home/bjoernf
            Platform                       Unix
            RootWorkingDirectory           /home/bjoernf/DryDeploy
            Edition                        Core
            Version                        7.5.1
        #>
        $AnsibleWsl = $false
        if($GLOBAL:dry_var_global_Platform.Platform -eq 'Win32NT'){
            # we need to run the ansible playbook in wsl
            $AnsibleWsl = $true
        }

        <#
        [linux_servers]
server1.example.com ansible_connection=ssh ansible_user=myuser

[windows_servers]
winserver.example.com ansible_connection=winrm ansible_user=Administrator ansible_password=SecurePass ansible_winrm_transport=ntlm
        #>
        
        
        # the entrypoint of the ansible playbook must be the main.yml at root
        switch($AnsibleWsl){
            $true {
                $AnsiblePlaybookPath = $Resolved.WslConfigSourcePath + "/main.yml"
            
                # ansible inventory ini file in powershell on windows and the wsl equivalent
                $TargetInventoryFile = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($Action.Resource.Name)-inv.ini"
                $wslTargetInventoryFile = $Resolved.WslConfigTargetPath + "/$($Action.Resource.Name)-inv.ini"
                
                # ansible log file in powershell on windows and the wsl equivalent
                $AnsibleLogFile = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($Action.Resource.Name)-ansible.log"
                $wslAnsibleLogFile = $Resolved.WslConfigTargetPath + "/$($Action.Resource.Name)-ansible.log"
            }
            $false {
                $AnsiblePlaybookPath = $Resolved.ConfigSourcePath + "/main.yml"
                
                # ansible inventory ini and log file paths
                $TargetInventoryFile = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($Action.Resource.Name)-inv.ini"
                $AnsibleLogFile = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($Action.Resource.Name)-ansible.log"

                # not running in wsl, these path are just the same
                $wslTargetInventoryFile = $TargetInventoryFile
                $wslAnsibleLogFile = $AnsibleLogFile
            }
        }
        
        # remove files that may exist from a previous run
        if(Test-Path -Path $Resolved.ConfigTargetPath -ErrorAction Ignore){
            Remove-Item -Path $Resolved.ConfigTargetPath -Recurse -Force -Confirm:$false
        }
        
        # create the target folder
        if(-not (Test-Path -Path $Resolved.ConfigTargetPath -ErrorAction Ignore)){
            New-Item -Path $Resolved.ConfigTargetPath -ItemType Directory -Confirm:$false -Force | Out-Null
        }

        # output to screen 
        ol i @('Ansible playbook entrypoint',"$AnsiblePlaybookPath")
        ol i @('Inventory file path',"$wslTargetInventoryFile")
        ol i @('Log file path',"$wslAnsibleLogFile")

        # start creating contents of inventory file
        $AnsibleTargetString = "$($Resolved.Target) ansible_connection=$AnsibleConnectionType ansible_user=$($Resolved.Credentials.credential1.GetNetworkCredential().UserName) ansible_log_path=$wslAnsibleLogFile"
        if($AnsibleAuthenticationType -eq 'key'){
            $AnsibleTargetString += " ansible_ssh_private_key_file=how_do_we_do_this"
        }
        if($AnsibleConnectionType -eq 'psrp'){
            $DefaultPSRPPort = 5985
            $DefaultPSRPProtocol = 'http'
            if($Resolved.TypeMetaConfig.psrp_protocol -eq 'https'){
                $DefaultPSRPPort = 5986
                $DefaultPSRPProtocol = 'https'
            }

            if($null -eq $Resolved.TypeMetaConfig.psrp_protocol){
                $ResolvedProtocol = $DefaultPSRPProtocol
            }
            else{
                $ResolvedProtocol = $Resolved.TypeMetaConfig.psrp_protocol
            }
            if($null -eq $Resolved.TypeMetaConfig.psrp_port){
                $ResolvedPort = $DefaultPSRPPort
            }
            else{
                $ResolvedPort = $Resolved.TypeMetaConfig.psrp_port
            }
            
            $AnsibleTargetString += " ansible_psrp_protocol=$($ResolvedProtocol)"
            $AnsibleTargetString += " ansible_psrp_port=$($ResolvedPort)"
            $AnsibleTargetString += " ansible_psrp_cert_validation=ignore"
        }

        #ansible_psrp_protocol
        #ansible_psrp_port

        
        # the inventory file content
        $InventoryINIContent = @"
# Ansible Inventory file for $($Action.Resource.Name)   
[$($Action.Resource.Name)]
$AnsibleTargetString

[$($Action.Resource.Name):vars]

"@     
        # variables that are not secrets are written to the inventory file
        foreach($var in $Resolved.vars | Where-Object{ $_.secret -eq $false}){
            $InventoryINIContent += "$($var.Name)=$($var.Value)`n"
        }
    
        # write the inventory file using UTF8 without BOM
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        [system.io.file]::WriteAllLines($TargetInventoryFile, $InventoryINIContent, $Utf8NoBomEncoding)
        ol i @('Ansible Inventory file written',"$TargetInventoryFile")

        # ansible-playbook arguments
        [system.collections.arraylist]$Arguments = @(
            "-i", 
            $wslTargetInventoryFile, 
            $AnsiblePlaybookPath,
            "--extra-vars", 
            "`"ansible_password=$($Resolved.Credentials.credential1.GetNetworkCredential().Password) ansible_become_pass=$($Resolved.Credentials.credential1.GetNetworkCredential().Password)`""
        )

        # the meta config allows you to specify a number of seconds to sleep before contacting the target
        if($Resolved.TypeMetaConfig.sleep_before_seconds){
            Start-DryUtilsSleep -Seconds $Resolved.TypeMetaConfig.sleep_before_seconds -Message "Sleeping $($Resolved.TypeMetaConfig.sleep_before_seconds) seconds before contacting target"
        }
       
        # add target to known_hosts
        ol i "Add the target [$($Action.Resource.Name) ($($Resolved.Target))] to known_hosts" -sh
        if($true -eq $AnsibleWsl){
            ol i @('command',"Start-Process 'wsl' -ArgumentList `"-d Ubuntu -- ssh-keyscan -H $($Resolved.Target) >> ~/.ssh/known_hosts`" -NoNewWindow -Wait")
            Start-Process 'wsl' -ArgumentList "-d Ubuntu -- ssh-keyscan -H $($Resolved.Target) >> ~/.ssh/known_hosts" -NoNewWindow -Wait
        }
        else{
            ol i @('command',"ssh-keyscan -H $($Resolved.Target) >> ~/.ssh/known_hosts")
            Start-Process 'ssh-keyscan' -ArgumentList "-H $($Resolved.Target) >> ~/.ssh/known_hosts" -NoNewWindow -Wait
        }
        

        # run the playbook
        ol i "Run the ansible-playbook" -sh
         if($true -eq $AnsibleWsl){
            ol i @('command',"Start-Process 'wsl' -ArgumentList `"-d Ubuntu -- export ANSIBLE_LOG_PATH=$wslAnsibleLogFile; ansible-playbook $Arguments -vvvv`" -NoNewWindow -Wait")
            Start-Process 'wsl' -ArgumentList "-d Ubuntu -- export ANSIBLE_LOG_PATH=$wslAnsibleLogFile; ansible-playbook $Arguments" -NoNewWindow -Wait
         }
         else{
            #ol i @('command',"Start-Process 'sh' -ArgumentList `"export ANSIBLE_LOG_PATH=$wslAnsibleLogFile; ansible-playbook $Arguments -vvvv`" -NoNewWindow -Wait")
            #Start-Process 'sh' -ArgumentList "export ANSIBLE_LOG_PATH=$wslAnsibleLogFile; ansible-playbook $Arguments" -NoNewWindow -Wait
            #ol i @('command',"& export ANSIBLE_LOG_PATH=$wslAnsibleLogFile")
            #& export ANSIBLE_LOG_PATH=$wslAnsibleLogFile

            ol i @('command',"& ansible-playbook $Arguments")
            Start-Process 'sh' -ArgumentList "ansible-playbook $Arguments" -NoNewWindow -Wait
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