<#
 This module establishes sessions to target machines for use by DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function Test-DryWinRM{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,HelpMessage="IP, FQDN or NetBIOS Host Name")]
        [string]$Computername,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [PSObject]$SessionConfig
    )
    [Bool]$AvailableSession = $false
    try{
        $NewDrySessionParams = @{
            ComputerName  = $ComputerName
            Credential    = $Credential
            SessionConfig = $SessionConfig
            SessionType   = 'PSSession'
            IgnoreErrors  = $true
            MaxRetries    = 3
        }
        $Session = New-DrySession @NewDrySessionParams
        if($Session.Availability -eq "Available"){
            $AvailableSession = $true
            $Session | Remove-PSSession -ErrorAction Ignore
        }
        $AvailableSession
    }
    catch{
        $AvailableSession
    }
}