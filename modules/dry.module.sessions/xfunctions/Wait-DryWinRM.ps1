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

function Wait-DryWinRM{
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage="IP-address")]
        [string]$IP,

        [Parameter(Mandatory,HelpMessage="NetBIOS Host Name")]
        [string]$Computername,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential[]]$Credential,

        [Parameter(HelpMessage="Port - defaults to 5985")]
        [int]$Port = 5985,

        [Parameter(HelpMessage="How long (in seconds) do you 
        want me to try reaching the interface? Default is 1800 (30 minutes)")]
        [int]$SecondsToTry = 1800,

        [Parameter(HelpMessage="How long (in seconds) do you 
        want me to wait before I start? By default, I wait 15 seconds")]
        [int]$SecondsToWaitBeforeStart = 15,

        [Parameter(HelpMessage="How long (in seconds) do you 
        want me to wait between each retry? By default, I wait 60 seconds")]
        [int]$SecondsToWaitBetweenTries = 60,

        [Parameter()]
        [PSObject]$SessionConfig
    )
    if($IP){
        $Address = $IP
    } 
    else{
        $Address = $ComputerName
    }
    $StartTime = Get-Date
    
    # if, for instance, a restart is required in the midst of all of this, the function may
    # return true too early, so we sleep a specified number of seconds before checking 
    for ($Timer = 1; $Timer -lt $SecondsToWaitBeforeStart; $Timer++){
        $WriteProgressParameters = @{
            Activity        = "[$Address`:$Port]: Waiting for WinRM interface"
            Status          = "Waiting $($SecondsToWaitBeforeStart-$Timer) seconds before starting"
            PercentComplete = (($Timer / $SecondsToWaitBeforeStart) * 100 )   
        }
        Write-Progress @WriteProgressParameters
        Start-Sleep -seconds 1
    }
    Write-Progress -Completed -Activity "[$Address`:$Port]: Waiting for WinRM interface"
    
    [datetime]$TargetTime = (Get-Date).AddSeconds($SecondsToTry)
    ol i 'Waiting until',"$TargetTime ($SecondsToTry seconds from now)"

    [bool]$WinRMUp = $false
    [bool]$PortUp = $false

    do{
        $ProgressTotalTime = [int]((New-TimeSpan -Start $StartTime -End $TargetTime).TotalSeconds)
        $ProgressTimeLeft = [int]((New-TimeSpan -Start (Get-Date) -end $TargetTime).TotalSeconds)
        $WriteProgressParameters = @{
            Activity        = "[$Address`:$Port]: Waiting for WinRM interface"
            Status          = "Port Down"
            PercentComplete = ((($ProgressTotalTime-$ProgressTimeLeft) / $ProgressTotalTime) * 100)   
        }   
        Write-Progress @WriteProgressParameters    
        
        if((Test-DryUtilsPort -Port $Port -ComputerName $Address -ErrorAction SilentlyContinue).Open -eq $true){
            $PortUp = $true
            do{
                $StartInPSSessionParams = @{
                    Command       = 'Write-Output'
                    Arguments     = @{'InputObject'='hei'}
                    Computername  = $Address
                    Credential    = $Credential
                    SessionConfig = $SessionConfig
                    IgnoreErrors  = $true
                } 
                $ReturnValue = Invoke-DryInPSSession @StartInPSSessionParams 
                if($ReturnValue -eq 'hei'){
                    $WinRMUp = $true
                    Write-Progress -Completed -Activity "[$Address`:$Port]: Waiting for WinRM interface"
                }
                else{
                    $NowTime = Get-date 
                    $Span = [int]((New-TimeSpan -Start $StartTime -End $NowTime).TotalSeconds)
                    
                    if($NowTime -lt $TargetTime){
                
                        ol i "Still waiting for WinRM","$Span of $ProgressTotalTime seconds"
                        $ProgressTimeLeft = [int]((New-TimeSpan -Start (Get-Date) -end $TargetTime).TotalSeconds)
                        $WriteProgressParameters = @{
                            Activity        = "[$Address`:$Port]: Waiting for WinRM interface"
                            Status          = "WinRM Down"
                            PercentComplete = ((($ProgressTotalTime-$ProgressTimeLeft) / $ProgressTotalTime) * 100 )   
                        }   
                        Write-Progress @WriteProgressParameters  
                        Start-Sleep -Seconds $SecondsToWaitBetweenTries
                    }
                }
            }
            while (
                ($WinRMUp -eq $false) -and 
                ((Get-Date) -lt $TargetTime)
            )
        }
        else{
            $NowTime = Get-date 
            $Span = [int]((New-TimeSpan -Start $StartTime -End $NowTime).TotalSeconds)
            
            if($(Get-Date) -lt $TargetTime){
                ol i "Still waiting for WinRM","$Span of $ProgressTotalTime seconds"
                Start-Sleep -Seconds $SecondsToWaitBetweenTries
            }
            else{
                Write-Progress -Completed -Activity "[$Address`:$Port]: Waiting for WinRM interface"
            }
        } 
    }
    while (  ($portUp -eq $false)  -and ((Get-Date) -lt $TargetTime) )
    
    switch($WinRMUp){
        $true{ ol i "WinRM status","UP" }
        $false{ ol i "WinRM status","DOWN"}
    }
    return $WinRMUp
}