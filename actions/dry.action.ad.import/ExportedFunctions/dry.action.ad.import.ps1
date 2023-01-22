Using Module dry.module.ad
# Using Module ActiveDirectory
# Using Module GroupPolicy
function dry.action.ad.import {
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
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            Execution Type 
            
            In a Greenfield deployment, this is running an a computer outside the domain
            and we must remote into a domain controller to execute each configuration
            action. However, if this is running on a domain member in that domain, we
            assume that the config  may run locally. The DryAD module supports both 
            'Local' and 'Remote' execution. The Get-DryAdExecutionType query function
            tests if the prerequisites for a Local execution is there
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        Enum ExecutionType { Local; Remote }        
        [ExecutionType]$ExecutionType = Get-DryAdExecutionType -Configuration $Configuration
        ol i 'Execution Type',$ExecutionType

        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
           Resolve Active Directory Connection Point
           ad.import will target a domain controller on the site the resource belongs to
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        $GetDryADConnectionPointParams = @{
            Resource      = $Action.Resource 
            Configuration = $Configuration 
            ExecutionType = $ExecutionType
        }
        if ($ExecutionType -eq 'Remote') {
            $GetDryADConnectionPointParams += @{
                Credential = $Resolved.Credentials.credential1
            }
        }
        $ActiveDirectoryConnectionPoint = Get-DryADConnectionPoint @GetDryADConnectionPointParams
        ol i "Connection Point (Domain Controller)",$ActiveDirectoryConnectionPoint
        
        # Wait for the winrm interface to come up
        if ($ExecutionType -eq 'Remote') {
            $SessionConfig = $Configuration.CoreConfig.connections | Where-Object { 
                $_.type -eq 'winrm'
            }
            $WaitWinRMParams             = @{
                IP                       = $ActiveDirectoryConnectionPoint
                Computername             = $Action.Resource.name
                Credential               = $Resolved.Credentials.credential1
                SecondsToTry             = 1800
                SecondsToWaitBeforeStart = 2
                SessionConfig            = $SessionConfig
            }
            $WinRMStatus = Wait-DryWinRM @WaitWinRMParams

            switch ($WinRMStatus) {
                $false {
                    throw "Failed to Connect to: $ActiveDirectoryConnectionPoint"
                }
                $true {
                    ol i @("Connected to","$ActiveDirectoryConnectionPoint")
                }  
            }
            
            # Create session to run the configuration in
            $ADImportSessionParams += @{
                SessionType   = 'PSSession'
                ComputerName  = $ActiveDirectoryConnectionPoint
                Credential    = $Resolved.Credentials.credential1
                SessionConfig = $SessionConfig
            }
    
            try {
                ol i "Establishing PSSession to","$ActiveDirectoryConnectionPoint"
                $PSSession = New-DrySession @ADImportSessionParams
            }
            catch {
                ol e @('Failed to establish PSSession to',"$ActiveDirectoryConnectionPoint")
                $PSCmdLet.ThrowTerminatingError($_)
            }
        }
        
        $SetDryADConfigurationParams = @{
            Variables         = $Resolved.vars
            ConfigurationPath = $Resolved.ConfigSourcePath
            ComputerName      = $Action.Resource.name
            ADSite            = $Action.Resource.resolved_network.site
            DryDeploy         = $true
        }
        if ($ExecutionType -eq 'Remote') {
            $SetDryADConfigurationParams += @{
                PSSession = $PSSession
            }
        }
        else {
            $SetDryADConfigurationParams += @{
                DomainController = $ActiveDirectoryConnectionPoint
            }
        }

        if ($ActionParams) {
            $SetDryADConfigurationParams+=$ActionParams
        }
        ol d "Calling 'Import-DryADConfiguration' with the following splat"
        ol d -hash $SetDryADConfigurationParams
        Import-DryADConfiguration @SetDryADConfigurationParams
        $PSSession | Remove-PSSession -ErrorAction continue
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        @('ActiveDirectory','GroupPolicy','GPOManagement','RegistryPolicyParser','dry.module.ad'
        ).foreach({
            Remove-Module -Name $_ -ErrorAction 'Ignore' -Verbose:$false |
            Out-Null
        })

        @(Get-Variable -Scope Script).foreach({
            $_ | Remove-Variable -ErrorAction Ignore
        })
        
        ol i "Action 'ad.import' is finished" -sh
    }
}