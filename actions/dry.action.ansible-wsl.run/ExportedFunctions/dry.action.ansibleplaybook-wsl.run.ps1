Using Namespace System.Collections.Generic
Using Namespace System.Management.Automation
Using Namespace System.IO
function dry.action.ansibleplaybook-wsl.run {
    [CmdletBinding()]  
    param (
        [Parameter(Mandatory,HelpMessage="The resolved action object")]
        [PSObject]$Action,

        [Parameter(Mandatory)]
        [PSObject]$Resolved,

        [Parameter(Mandatory,HelpMessage="The resolved global configuration object")]
        [PSObject]$Configuration,

        [Parameter(HelpMessage="Hash directly from the command line to be added 
        as parameters to the program that executes the action")]
        [HashTable]$ActionParams
    )
    try {
        Push-Location
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            SourceFile is the top .tf file
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        [string]$SourceFilePath = Join-Path -Path $Resolved.ConfigSourcePath -ChildPath '*'
        [FileInfo]$SourceFile = Get-Item -Path $SourceFilePath -Include "*.tf" -ErrorAction Stop
        [string]$TargetVarsFile = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($Action.Resource.Name).vars.yml"
        #[string]$TargetStateFile = Join-Path -Path $Resolved.ConfigTargetPath -ChildPath "$($Action.Resource.Name).tfstate"
        [HashTable]$VariablesHash = ConvertTo-DryHashtable -Variables $Resolved.vars -NotSecrets
        
        # Output the vars file using yml. Using utf8 by default, but allow the configuration to modify that by specifying ansible_encoding 
        $Encoding = 'utf8'
        if ($Resolved.MetaConfig.ansible_encoding) {
            $Encoding = $Resolved.MetaConfig.ansible_encoding
        }
        $VariablesHash | 
        ConvertTo-Json -Depth 50 -ErrorAction Stop | 
        Out-File -FilePath $TargetVarsFile -Encoding $Encoding -ErrorAction Stop -Force
        
        Set-Location -Path $Resolved.ConfigSourcePath -ErrorAction Stop

        # Terraform Init
        & terraform init 
        if ($LastExitCode -ne 0) {
            throw "Terraform Init failed: $LastExitCode" 
        }
        
        # Terraform Validate
        & terraform validate
        if ($LastExitCode -ne 0) {
            throw "Terraform Validate failed: $LastExitCode" 
        }

        # Terraform Apply
        [Array]$Arguments = @()
        foreach ($Var in $Resolved.vars | Where-Object { $_.secret -eq $true}) {
            $Arguments += "-var"
            $Arguments += "$($Var.Name)=`"$($Var.Value)`""
        }
        $Arguments += "-state=$TargetStateFile"
        $Arguments += "-var-file=$TargetVarsFile"

        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            ActionParams
            When working with a single Action type, for instance during development, 
            it is possible to pass a hashtable of extra commmand line paramaters to 
            DryDeploy.ps1 that will be passed to the receiving program, in this case 
            Terraform.  
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
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
                    $Arguments += "-$($ActionParam.Name)" # Switch
                }
                else {
                    $Arguments += "-$($ActionParam.Name)=$($ActionParam.Value)" # Key-Value pair
                }
            }
        }

        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            Terraform Apply - apply the config
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        ol v "Ready to run terraform apply - the command is shown below"
        ol v "& terraform apply -auto-approve $Arguments"
        & terraform apply -auto-approve $Arguments
        if ($LastExitCode -ne 0) {
            throw "Terraform Apply failed: $LastExitCode" 
        }
        else {
            <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                if dhcp, update the resource with IP from terraform
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
            if ($Action.Resource.Resolved_Network.IP_Address -eq 'dhcp') {
                ol v "Getting IP of the resource"
                $StateObj = $null 
                $StateResource = $null
                $StateObj = Get-Content -Path $TargetStateFile | ConvertFrom-Json
                $StateResource = $StateObj.Resources | Where-Object {
                    $_.instances.attributes.name -eq $Action.Resource.Name
                }
                if ($null -eq $StateResource) {
                    ol w @("Unable to find resource in state",$Action.Resource.Name)
                }
                else {
                    if ($null -ne $StateResource.instances.attributes.default_ip_address) {
                        ol i @("Resource found in state with IP",$StateResource.instances.attributes.default_ip_address)
                        $GLOBAL:dry_var_global_ResolvedIPv4 = $StateResource.instances.attributes.default_ip_address
                    }
                    else {
                        ol w @("Resource found in state, but no IP",$Action.Resource.Name)
                    }
                }
            }
        }   
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        Pop-Location
        if ($GLOBAL:dry_var_global_KeepConfigFiles) {
            ol i @('Keeping ConfigFiles in',"$ConfigTargetPath")
        }
        else {
            #ol i @('Removing ConfigFiles from',"$ConfigTargetPath")
            # Remove-Item -Path $ConfigTargetPath -Recurse -Force -Confirm:$false
        }
        $SourceFilePath = $null
        $SourceFile = $null
        $TargetVarsFile = $null 
        $TargetStateFile = $null 
        $VariablesHash = $null
        $Encoding = $null 
        $Resolved = $null
        $Arguments = $null 
        $ActionParams = $null
        ol i "Action 'ansible-wsl.run' is finished" -sh
    }
}