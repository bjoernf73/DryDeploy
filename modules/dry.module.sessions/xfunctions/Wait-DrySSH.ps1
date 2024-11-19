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

function Wait-DrySSH {
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage="IP Address")]
        [string]
        $IP,

        [Parameter(Mandatory,HelpMessage="NetBIOS Host Name")]
        [string]
        $Computername,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter(HelpMessage="Port - defaults to 22")]
        [int]
        $Port = 22,

        [Parameter(HelpMessage="How long (in seconds) do you want me to try reaching the interface? Default is 1800 (30 minutes)")]
        [int]
        $SecondsToTry = 1800,

        [Parameter(HelpMessage="How long (in seconds) do you want me to wait before I start? By default, I wait 15 seconds")]
        [int]
        $SecondsToWaitBeforeStart = 15,

        [Parameter(HelpMessage="How long (in seconds) do you want me to wait between each retry? By default, I wait 60 seconds")]
        [int]
        $SecondsToWaitBetweenTries = 30
    )
    if ($IP) {
        $Address = $IP
    } 
    else {
        $Address = $ComputerName
    }
    
    ol i 'Waiting for SSH interface' -sh
    ol i 'Address and port',"$Address`:$Port"
    $StartTime = Get-Date
    
    # if, for instance, a restart is required in the midst of all of this, the function may
    # return true too early, so we sleep a specified number of seconds before checking 
    # increment the element counter and update progress
    for ($Timer = 1; $Timer -lt $SecondsToWaitBeforeStart; $Timer++) {
        $WriteProgressParameters = @{
            Activity        = "Testing SSH Interface on '$Address'"
            Status          = "Waiting $($SecondsToWaitBeforeStart-$Timer) seconds before starting"
            PercentComplete = (($Timer / $SecondsToWaitBeforeStart) * 100 )   
        }
        Write-Progress @WriteProgressParameters
        Start-Sleep -seconds 1
    }
    Write-Progress -Completed -Activity "[$Address`:$Port]: Waiting for SSH interface"
    
    
    # Target time
    [datetime]$TargetTime = (Get-Date).AddSeconds($SecondsToTry)
    ol i "I will try until","$TargetTime"

    [bool]$SSHUp = $false
    [bool]$PortUp = $false

    # Outter do tests if the port is up
    do {
        $ProgressTotalTime = [int]((New-TimeSpan -Start $StartTime -End $TargetTime).TotalSeconds)
        $ProgressTimeLeft = [int]((New-TimeSpan -Start (Get-Date) -end $TargetTime).TotalSeconds)
        $WriteProgressParameters = @{
            Activity        = "[$Address`:$Port]: Waiting for SSH interface"
            Status          = "Port Down"
            PercentComplete = ((($ProgressTotalTime-$ProgressTimeLeft) / $ProgressTotalTime) * 100 )   
        }   
        Write-Progress @WriteProgressParameters    
        
        # First, the port must be up
        if ((Test-DryUtilsPort -Port $port -ComputerName $Address -ErrorAction SilentlyContinue).Open -eq $true) {
            $PortUp = $true
            # Inner do test if SSH is actually usable
            do {
                $SSHParams = @{
                    ComputerName     = $Address
                    Credential       = $Credential
                    Port             = $Port
                    ErrorOnUntrusted = $false
                    Force            = $true
                }

                $SSHSession = New-SSHSession @SSHParams -ErrorAction Continue
                $SSHSession
                if ($SSHSession.Connected -eq $true) {
                    $SSHUp = $true
                    $SSHSession | Remove-SSHSession -ErrorAction SilentlyContinue
                }
                else {
                    ol i "Connection is: '$($SSHSession.Connected)'"
                    $NowTime = Get-date 
                    $Span = [int]((New-TimeSpan -Start $StartTime -End $NowTime).TotalSeconds)
                    $TimeLeft = [int]((New-TimeSpan -Start $NowTime -end $TargetTime).TotalSeconds)
                    
                    # sleep and let loop retry
                    if ($NowTime -lt $TargetTime) {
                        ol i "[$Address`:$Port]: Still waiting (SSH not ready). Been waiting for $Span of $TimeLeft seconds"
                        $ProgressTimeLeft = [int]((New-TimeSpan -Start (Get-Date) -end $TargetTime).TotalSeconds)
                        $WriteProgressParameters = @{
                            'Activity'="[$Address`:$Port]: Waiting for SSH interface"
                            'Status'="SSH Down"
                            'PercentComplete'=((($ProgressTotalTime-$ProgressTimeLeft) / $ProgressTotalTime) * 100 )   
                        }   
                        Write-Progress @WriteProgressParameters    
                        Start-Sleep -Seconds $SecondsToWaitBetweenTries
                    }
                    else {
                        ol i "[$Address`:$Port]: Been waiting for $Span seconds - time's up - there's no point to this"
                    }
                
                }
            }
            while ( ($SSHUp -eq $false)  -and ((Get-Date) -lt $TargetTime) )
        }
        else {
            $NowTime = Get-date 
            $Span = [int]((New-TimeSpan -Start $StartTime -End $NowTime).TotalSeconds)
            $TimeLeft = [int]((New-TimeSpan -Start $NowTime -end $TargetTime).TotalSeconds)
            
            # sleep and let loop retry
            if ($(Get-Date) -lt $TargetTime) {
                ol i "[$Address`:$Port]: Still waiting (port not up). Been waiting for $Span of $TimeLeft seconds"
                Start-Sleep -Seconds $SecondsToWaitBetweenTries
            }
            else {
                ol i "[$Address`:$Port]: Been waiting for $Span seconds - time's up - there's no point to this"
                Write-Progress -Completed -Activity "[$Address`:$Port]: Waiting for SSH interface"
            }
        } 
    }
    while (  ($portUp -eq $false)  -and ((Get-Date) -lt $TargetTime) )
    
    $EndTime = Get-Date
    $TotalMinutes = ($EndTime - $StartTime).minutes
    ol v "[$Address`:$Port]: Waited a total of $TotalMinutes minutes. Status is '$State'"
    
    switch ($SSHUp) {
        $true { 
            ol i "[$Address`:$Port]: SSH is UP"
            $true
        }
        $false {
            ol i "[$Address`:$Port]: SSH is DOWN"
            $false
        }
    }
}