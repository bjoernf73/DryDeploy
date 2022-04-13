<# 
 This module provides generic functions for use with DryDeploy.

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


function Wait-DryForEvent {
    [cmdletbinding()]            
    param (
        [Parameter(HelpMessage="Array of Hashtables containing identifying values for the Event. Should contain any `
        combinations (one or more) of the following: LogName, EventID, Source, Message, EntryType `
        LogName is mandatory")]
        [hashtable[]]$Filters,

        [Parameter(HelpMessage="How many seconds to try before I fail")]
        [Int]$SecondsToTry = 300,

        [Parameter(HelpMessage="How many seconds to wait between tries")]
        [Int]$SecondsToWaitBetweenTries = 30,

        [Parameter(HelpMessage="How many seconds to wait before I start trying? By default, I wait 15 seconds")]
        [Int]$SecondsToWaitBeforeStart = 15,

        [Parameter(Mandatory,HelpMessage="Parameters to splat to New-DrySession")]
        [Hashtable]$SessionParameters
    )

    $Session = New-DrySession @SessionParameters
    ol i "Searching Event Log for $SecondsToTry seconds for the following events:"
    ol i "..............................."
   
    # Preprocess Filter properties
    foreach ($Filter in $Filters) {

        # If 'AfterBoot' is $True, I will create a datetime object of the last boot time, and use
        # that as the After-parameter. If in addition 'SecondsAfter' is specified, I will subtract
        # that number of seconds from the boot time. 
        if (($Filter.ContainsKey('AfterBoot')) -and ($Filter['AfterBoot'] -eq $True)) {
            
            $LastBootTime = Get-DryLastBootTime -Session $Session
            
            if ($Filter.ContainsKey('SecondsAfter')) {
                $Filter['After'] = $LastBootTime.AddSeconds(-$($Filter['SecondsAfter']))
                $Filter.Remove('SecondsAfter')
            }
            else {
                $Filter['After'] = $LastBootTime
            }

            if ($Filter.ContainsKey('SecondsBefore')) {
                ol w "You cannot specify both AfterBoot and SecondsBefore - use BeforeBoot and optionally SecondsBefore instead"
                $Filter.Remove('SecondsBefore')
            }
        }
        # If 'BeforeBoot' is $True, I will create a datetime object of the last boot time, and use
        # that as the Before-parameter. If in addition 'SecondsBefore' is specified, I will subtract
        # that number of seconds from the boot time. 
        elseif (($Filter.ContainsKey('BeforeBoot')) -and ($Filter['BeforeBoot'] -eq $True)) {
            # Get time of last boot
            $LastBootTime = Get-DryLastBootTime -Session $Session
            
            if ($Filter.ContainsKey('SecondsBefore')) {
                $Filter['Before'] = $LastBootTime.AddSeconds(-$($Filter['SecondsBefore']))
                $Filter.Remove('SecondsBefore')
            }
            else {
                $Filter['Before'] = $LastBootTime
            }

            if ($Filter.ContainsKey('SecondsAfter')) {
                ol w "You cannot specify both BeforeBoot and SecondsAfter - use AfterBoot and optionally SecondsAfter instead"
                $Filter.Remove('SecondsAfter')
            }
        }

        elseif ($Filter.ContainsKey('SecondsBefore')) {
            $Filter['Before'] = (Get-Date).AddSeconds(-$($Filter['SecondsBefore']))
            $Filter.Remove('SecondsBefore')
            
            if ($Filter.ContainsKey('SecondsAfter')) {
                ol w "You cannot specify both SecondsBefore and SecondsAfter"
                $Filter.Remove('SecondsAfter')
            }
        }

        elseif ($Filter.ContainsKey('SecondsAfter')) {
            $Filter['After'] = (Get-Date).AddSeconds(-$($Filter['SecondsAfter']))
            $Filter.Remove('SecondsAfter')
        } 
        
        @('LogName','EventID','Source','EntryType','Message','Before','After') | 
        foreach-Object {
            if ($Filter.ContainsKey("$_")) {
                $str = "$_`:"
                do {
                    $str = "$str "
                } while ($str.Length -lt 14)
            }
        }
        # Add the Found bool to the filter
        $Filter['Found'] = $False
    }

    # Remove the session used so far. Create a new session at each try to avoid broken sessions
    $Session | Remove-PSSession -ErrorAction Ignore

    $StartTime = Get-Date
    
    # If, for instance, a restart is required in the midst of all of this, the function may
    # return true too early, so we sleep a specified number of seconds before checking 
    # increment the element counter and update progress
    for ($Timer = 1; $Timer -lt $SecondsToWaitBeforeStart; $Timer++) {
        $WriteProgressParameters = @{
            'Activity'="Waiting"
            'Status'="Waiting $($SecondsToWaitBeforeStart-$Timer) seconds before starting"
            'PercentComplete'=(($Timer / $SecondsToWaitBeforeStart) * 100 )   
        }
        Write-Progress @WriteProgressParameters
        Start-Sleep -seconds 1
    }
    Write-Progress -Completed -Activity "Waiting"

    # Set the target time
    [datetime] $TargetTime = (Get-Date).AddSeconds($SecondsToTry)
    ol i "Searching until:  $TargetTime"

    [Bool] $Found       = $false
    [Int]  $FoundCount  = 0
    [Int]  $TargetCount = $Filters.count
    [Int]  $Tried       = 0

    try {
        do {
            $Tried++
            ol i "Try nr. $Tried"
            $ProgressTotalTime = [Int]((New-TimeSpan -Start $StartTime -End $TargetTime).TotalSeconds)
            $ProgressTimeLeft = [Int]((New-TimeSpan -Start (Get-Date) -end $TargetTime).TotalSeconds)
            $WriteProgressParameters = @{
                'Activity'="Searching"
                'Status'="Searching Event Log"
                'PercentComplete'=((($ProgressTotalTime-$ProgressTimeLeft) / $ProgressTotalTime) * 100 )   
            }   
            Write-Progress @WriteProgressParameters    
            
            foreach ($Filter in ($Filters | Where-Object {$_['Found'] -eq $False})) {
                $Session | Remove-PSSession -ErrorAction Ignore
                $Session = New-DrySession @SessionParameters
                $Found = Invoke-Command -Session $Session -ScriptBlock {
                    param ($Filter)
                    
                    # If EventID is used, put in $EventID
                    if ($Filter.ContainsKey('EventID')) {
                        $EventID = $Filter['EventID']
                    }
    
                    Remove-Variable -Name GetEventLogParameters -ErrorAction Ignore
                    $GetEventLogParameters = @{}
                    # $GetEventLogParameters += @{'Before'=$Before}
                    @('LogName','Source','EntryType','Message','After','Before') | 
                    foreach-Object {
                        if ($Filter.ContainsKey("$_")) {
                            $GetEventLogParameters += @{"$_"=$Filter["$_"]}
                        
                        }
                    }
                    
                    try {
                        Remove-Variable -Name Events -ErrorAction Ignore
                        if ($Null -eq $EventID) {
                            $Events = Get-EventLog @GetEventLogParameters -ErrorAction Ignore
                        }
                        else {
                            $Events = Get-EventLog @GetEventLogParameters -ErrorAction Ignore | 
                            Where-Object {
                                $_.EventID -eq $EventID
                            }
                        }
                        
                        if ($Events.count -ge 1) {
                            $True
                        } 
                        else {
                            $False
                        }
                    }
                    catch {
                        $False
                    }
                } -ArgumentList $Filter
    
                if ($Found) {
                    $FoundCount++
                    $Filter['Found'] = $True
                    ol i "Found verification Event with the following properties:"
                    @('LogName','EventID','Source','EntryType','Message','After','Before') | 
                    foreach-Object {
                        if ($Filter.ContainsKey("$_")) {
                            ol i "$_ = $($Filter[""$_""])"
                        }
                    }
                }
            }
            
            if ($FoundCount -lt $TargetCount) {
                ol i "Verification Events found: $FoundCount of $TargetCount. Sleeping $SecondsToWaitBetweenTries seconds before retrying..."
                Start-Sleep -Seconds $SecondsToWaitBetweenTries
            }
        }
        while (($FoundCount -lt $TargetCount) -and ((Get-Date) -lt $TargetTime))
        
        if ($FoundCount -lt $TargetCount) {
            ol i "Not all events found within the timeframe of $SecondsToTry seconds"
            throw "Not all events found within the timeframe of $SecondsToTry seconds"
        } 
        else {
            ol i "All Events found!"
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $Session | Remove-PSSession -ErrorAction Ignore
        Write-Progress -Completed -Activity "Searching"
    }
}