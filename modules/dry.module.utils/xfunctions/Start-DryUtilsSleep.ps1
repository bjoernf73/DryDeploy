<#
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function Start-DryUtilsSleep{
    [CmdletBinding()]
    param(
        [int]$Seconds,

        [string]$Message = "Sleeping $Seconds seconds..."
    )
    $TargetTime = (Get-Date).AddSeconds($Seconds)
    while($TargetTime -gt (Get-Date)){
        $SecondsLeft = $TargetTime.Subtract((Get-Date)).TotalSeconds
        $Percent = ($Seconds - $SecondsLeft) / $Seconds * 100
        Write-Progress -Activity "Sleeping" -Status "$Message" -SecondsRemaining $SecondsLeft -PercentComplete $Percent
        [System.Threading.Thread]::Sleep(500)
    }
    Write-Progress -Activity "Sleeping" -Status "Sleeping..." -SecondsRemaining 0 -Completed
}