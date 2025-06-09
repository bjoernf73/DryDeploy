<# 
 This module establishes sessions to target machines for use by DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
 
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License along
 with this program; if not, write to the Free Software Foundation, Inc.,
 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
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