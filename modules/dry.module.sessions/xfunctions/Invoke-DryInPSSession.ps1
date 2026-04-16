<#
 This module establishes sessions to target machines for use by DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function Invoke-DryInPSSession{
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName="Command",Mandatory)]
        [Parameter(ParameterSetName="Exe",Mandatory)]
        [string]$Command,

        [Parameter(ParameterSetName="Exe")]
        [string]$ArgumentString,

        [Parameter(ParameterSetName="Command")]
        [Parameter(ParameterSetName="scriptblock")]
        [hashtable]$Arguments,

        [Parameter(ParameterSetName="scriptblock",Mandatory)]
        [scriptblock]$Scriptblock,

        [Parameter(Mandatory)]
        [string]$Computername,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential[]]$Credential,

        [Parameter(Mandatory)]
        [PSObject]$SessionConfig,

        [Parameter(HelpMessage="Used by function that tests winrm interface")]
        [Switch]$IgnoreErrors

    )

    try{
        $GetDrySessionParameters = @{
            ComputerName  = $ComputerName
            Credential    = $Credential
            SessionConfig = $SessionConfig
            SessionType   = 'PSSession'
            IgnoreErrors  = $IgnoreErrors
        }
        $Session = New-DrySession @GetDrySessionParameters

        if($Session.Availability -eq "Available"){
            switch($pscmdlet.parametersetname){
                'Command'{
                    if($Arguments){
                        $Result = Invoke-Command -session $Session -ScriptBlock{
                            param($RemoteCommand,$RemoteArgumenstSplat)
                            return & ($RemoteCommand) @RemoteArgumenstSplat

                        } -ArgumentList $Command, $Arguments
                    }
                    else{
                        $Result = Invoke-Command -session $Session -ScriptBlock{
                            param($RemoteCommand)
                            return & ($RemoteCommand)

                        } -ArgumentList $Command
                    }
                }
                'scriptblock'{
                    if($Arguments){
                        $Result = Invoke-Command -session $Session -ScriptBlock $scriptblock -ArgumentList $Arguments
                    }
                    else{
                        $Result = Invoke-Command -session $Session -ScriptBlock $scriptblock
                    }
                }
                'Exe'{
                    if($Arguments){
                        $Result = Invoke-Command -session $Session -ScriptBlock{
                            param($RemoteCommand,$RemoteArgumenstString)
                            & ($RemoteCommand) $RemoteArgumenstString
                            return $LASTEXITCODE

                        } -ArgumentList $Command, $ArgumentString
                    }
                    else{
                        $Result = Invoke-Command -session $Session -ScriptBlock{
                            param($RemoteCommand)
                            & ($RemoteCommand)
                            return $LASTEXITCODE

                        } -ArgumentList $Command
                    }
                }
            }
        }
        else{
            if($IgnoreErrors){
                return $false
            }
            else{
                throw "Unable to start PSSession to $ComputerName"
            }
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
        $Session | Remove-PSSession -ErrorAction Ignore
        if($Result){
            $Result
        }
    }
}