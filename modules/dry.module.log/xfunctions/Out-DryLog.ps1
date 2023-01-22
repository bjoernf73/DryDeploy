<# 
 This module is contains logging and console output functions for DryDeploy. 

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.query/main/LICENSE
 
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

<#
.SYNOPSIS
A logging and output-to-display module for DryDeploy

.DESCRIPTION
A logging and output-to-display module for DryDeploy

.PARAMETER Type
Types follow Windows Streams, except for stream 1 (output) which isn't
used. You may also use first letter of a stream name, so type 2 and 'e'
are both the error stream, type 3 and 'w' the warning, and so on.
    Type 2 or 'e' = Error
    Type 3 or 'w' = Warning
    Type 4 or 'v' = Verbose
    Type 5 or 'd' = Debug
    Type 6 or 'i' = Information

.PARAMETER Message
The text to display and/or log.

.PARAMETER MsgHash
A hashtable to display and/or log

.PARAMETER MsgArr
A two-element array; for instance a hashtable key and it's corresponding value.
Out-DryLog will add whitespaces to the first element until it reaches a length
of `$LoggingOptions.array_first_element_length, which orders all second elements
in a straight vertical line. So basically for readability of a pair

.PARAMETER Header
Creates a line that seperates previous stuff from upcoming stuff, and then
displays the meader message, like:
..........................................................................
This is a normal header

.PARAMETER SmallHeader
Displays the header message, and then fills rest of the line with the header
chars, like

This is a small header  ..................................................

.PARAMETER Air
'Airs' the message in header or smallheader, converts 'Air' to 'A i r', like
..........................................................................
A i r e d   H e a d e r

.PARAMETER Callstacklevel
This function uses Get-PSCallstack to identify the location of the caller, i.e.
which function or script, and at what line, Out-DryLog was called. For certain
types (see parameter Type above) the function will then display that location on
the far right of each displayed line. You may configure for which types the
calling location should be displayed in `$LoggingOptions. Anyway, if a function
or many functions call the same proxy function that in turn calls Out-DryLog, it
may be more informative if the proxy function calls Out-DryLog with '-Callstacklevel 2'.
The effect is that the Location is no longer the PS Callstack element number 1 (the
proxy function), but element number 2 (the function that called the proxy function)

.EXAMPLE
Out-DryLog -Type 6 -Message "This is a type 6 (informational) message"

                              This is a type 6 (informational) message
.EXAMPLE
Out-DryLog 6 "This is a type 6 (informational) message"
                              This is a type 6 (informational) message

.EXAMPLE
ol 6 "This is a type 6 (informational) message"
                              This is a type 6 (informational) message

.EXAMPLE
$GLOBAL:GlobalResourceName = "DC001-S1-D"
$GLOBAL:GlobalActionName = "ProvisionDsc"
ol 6 "This is a type 6 (informational) message"
         [DC001-S1-D]:        [ProvisionDsc] This is a type 6 (informational) message

.EXAMPLE
ol 4 "This is a type 4 (verbose) message which won't display anything"


.EXAMPLE
ol 4 "This is a type 4 (verbose) message" -Verbose
VERBOSE: [DC001-S1-D]:        [ProvisionDsc] This is a type 4 (verbose) message               [MyScript.ps1:245 14:25:57]

.EXAMPLE
ol i 'This is an','arrayed message' ; ol i 'And this is','another one'
         [DC001-S1-D]:        This is an                       : arrayed message
         [DC001-S1-D]:        And this is                      : another one
#>
function Out-DryLog {
    [CmdletBinding(DefaultParameterSetName="message")]
    [Alias("ol")]
    param (
        [Alias("t")]
        [Parameter(Mandatory,Position=0)]
        [String]$Type,

        [Alias("m")]
        [Parameter(ParameterSetName="message",Mandatory,Position=1)]
        [AllowEmptyString()]
        [String]$Message,

        [Alias("hash")]
        [Parameter(ParameterSetName="hashtable",Mandatory,Position=1)]
        [hashtable]$MsgHash,

        [Alias("arr")]
        [Parameter(ParameterSetName="array",Mandatory,Position=1,
        HelpMessage="The 'MsgArr' parameter set expects an array of 2 elements, for instance a name or description of a
        value of some kind, and the second element is the value. Out-DryLog will add whitespaces to the first element
        until it reaches a length of `$LoggingOptions.array_first_element_length, which orders all second elements in
        a straight vertical line. So basically for readability of a pair")]
        [ValidateScript({"$($_.Count) -eq 2"})]
        [Array]$MsgArr,

        [Alias("obj")]
        [Parameter(ParameterSetName="object",Mandatory,Position=1,
        HelpMessage="Expects a very simple PSCustomObject with properties made up of strings, ints and bools. More complex types
        will be ignored")]
        [PSCustomObject]$MsgObj,

        [Alias("title")]
        [Parameter(ParameterSetName="hashtable",HelpMessage="Title of the Hashtable to display")]
        [Parameter(ParameterSetName="object",HelpMessage="Title of the PSObject to display")]
        [String]$MsgTitle,

        [Parameter(ParameterSetName="object", HelpMessage="Don't use this param. It is only for use in nested calls. 
        Meaning that the MsgObjLevel will be increased by 1 each time Out-DryLog parameterset 'object' calls itself")]
        [int]$MsgObjLevel = 1,

        [Alias("h")]
        [Parameter(ParameterSetName="message",HelpMessage="Creates a nice header of the message text")]
        [Switch]$Header,

        [Alias("hchar")]
        [Parameter(ParameterSetName="message",HelpMessage="The char(s) to fill the line")]
        [String]$HeaderChars = '.',

        [Alias("sh")]
        [Parameter(ParameterSetName="message",HelpMessage="Creates a nice, small header of the message text")]
        [Switch]$SmallHeader,

        [Alias("a")]
        [Parameter(ParameterSetName="message",HelpMessage="If -Header or -SmallHeader, converts 'Message' to 'M e s s a g e'")]
        [Switch]$Air,

        [Alias("cs")]
        [Parameter(HelpMessage="Normally 1, the direct caller. However, if Out-DryLog is called by a proxy function, you may use
        2 to point the 'location' (where in your code Out-DryLog was called) to the call before the direct call.")]
        [Int]$Callstacklevel = 1,

        [Alias("fore")]
        [AllowNull()]
        [Parameter(HelpMessage="Override the global options and the default fore color")]
        [System.ConsoleColor]$ForegroundColor,

        [Alias("back")]
        [AllowNull()]
        [Parameter(HelpMessage="Override the global options and the default fore color")]
        [System.ConsoleColor]$BackgroundColor
    )

    try {
        if ($null -eq $GLOBAL:LoggingOptions) {
            $GLOBAL:LoggingOptions = [PSCustomObject]@{
                log_to_file                = $true;
                path                       = & { if ($PSVersionTable.Platform -eq 'Unix') { "$($env:HOME)/DryDeploy/DryDeploy.log" } else { ("$($env:UserProfile)\DryDeploy\DryDeploy.log").Replace('\','\\')}};
                left_column_width          = 30;
                console_width_threshold    = 70;
                post_buffer                = 3;
                array_first_element_length = 45;
                verbose     = [PSCustomObject]@{ foreground_color = 'Cyan';     background_color = $null; display_location = $true;  text_type = 'VERBOSE:' }
                debug       = [PSCustomObject]@{ foreground_color = 'DarkCyan'; background_color = $null; display_location = $true;  text_type = 'DEBUG:  ' }
                warning     = [PSCustomObject]@{ foreground_color = 'Yellow';   background_color = $null; display_location = $true;  text_type = 'WARNING:' }
                information = [PSCustomObject]@{ foreground_color = 'White';    background_color = $null; display_location = $false; text_type = '        ' }
                error       = [PSCustomObject]@{ foreground_color = 'Red';      background_color = $null; display_location = $true;  text_type = 'ERROR:  ' }
                input       = [PSCustomObject]@{ foreground_color = 'Yellow';   background_color = $null; display_location = $true;  text_type = 'INPUT:  ' }
                success     = [PSCustomObject]@{ foreground_color = 'Green';    background_color = $null; display_location = $false; text_type = '        ' ;  status_text = 'Success'}
                fail        = [PSCustomObject]@{ foreground_color = 'Red';      background_color = $null; display_location = $false; text_type = '        ' ;  status_text = 'Fail'   }
            }
        }
        $LoggingOptions = $GLOBAL:LoggingOptions

        if ($LoggingOptions.log_to_file -eq $True) {
            if ($LoggingOptions.path) {
                $LogFile = $LoggingOptions.path
            }
            else {
                throw "You must define LoggingOptions.path to log to file"
            }
        }
        else {
            $LogFile = $null
        }

        # Check that $LogFile is defined, turn off logging to file if not
        if (($null -eq $LogFile) -or ($LogFile -eq "")) {
            # Only warn once, don't nag all the time
            if ($GLOBAL:DoNotLogToFile -ne $True) {
                Write-Warning -Message "`$LogFile is undefined -> logging to file is disabled. Define LoggingOptions.path to enable it!" -WarningAction Continue
                [Bool]$GLOBAL:DoNotLogToFile = $True
            }
        }
        else {
            # Make sure $LogFile exist if $GLOBAL:DoNotLogToFile -ne $True
            if (($GLOBAL:DoNotLogToFile -ne $True) -and (-not (Test-Path $LogFile))) {
                New-Item -ItemType File -Path $LogFile -Force -ErrorAction Stop | Out-Null
            }
        }

        # Get the calling cmdlet/script and line number
        $Caller = (Get-PSCallStack)[$callstacklevel]
        [String] $Location = ($Caller.location).Replace(' line ','')
        [String] $LocationString = "[$Location $(get-date -Format HH:mm:ss)]"

        $DisplayLogMessage = $False
        <#
            Windows Output Streams:
            1 OutPut/Success - not in use here
            2 Error
            3 Warning
            4 Verbose
            5 Debug
            6 Information
        #>
        $DisplayLogMessage = $True
        switch ($Type) {
            {$_ -in ('2','e','error')} {
                $Type = 'error'
            }
            {$_ -in ('3','w','warning')} {
                $Type = 'warning'
            }
            {$_ -in ('5','d','debug')} {
                $Type = 'debug'
                if ($PSBoundParameters.ContainsKey('Debug') -or 
                    ($PSCmdlet.GetVariableValue('DebugPreference') -eq 'Continue')) {
                }
                else {
                    $DisplayLogMessage = $false
                }
            }
            {$_ -in ('6','i','information','info')} {
                $Type = 'information'
            }
            {$_ -in ('s','success')} {
                $Type = 'success'
                $DisplayLogMessage = $GLOBAL:dry_var_global_ShowStatus
            }
            {$_ -in ('f','fail','failed')} {
                $Type = 'fail'
                $DisplayLogMessage = $GLOBAL:dry_var_global_ShowStatus
            }
            default {
                $Type = 'verbose'
                if ($PSBoundParameters.ContainsKey('Verbose') -or 
                    ($PSCmdlet.GetVariableValue('VerbosePreference') -eq 'Continue')) {
                }
                else {
                    $DisplayLogMessage = $false
                }
            }
        }

        if ($LoggingOptions."$Type".text_type) {
            $TextType = $LoggingOptions."$Type".text_type
        }
        if ($LoggingOptions."$Type".foreground_color) {
            $LOFore   = $LoggingOptions."$Type".foreground_color
        }
        if ($LoggingOptions."$Type".background_color) {
            $LOBack   = $LoggingOptions."$Type".background_color
        }
        if ($LoggingOptions."$Type".display_location) {
            $DisplayLocation = $LoggingOptions."$Type".display_location
        }

        if ($ForegroundColor) {
            $LOFore = $ForegroundColor
        }
        if ($BackgroundColor) {
            $LOBack = $BackgroundColor
        }
        [hashtable]$LogColors = @{}
        if ($null -ne $LOFore) {
            $LogColors += @{foregroundcolor = $LOFore}
        }
        if ($null -ne $LOBack) {
            $LogColors += @{backgroundcolor = $LOBack}
        }
            
        if ($DisplayLogMessage) {
            if (($null -ne $GLOBAL:GlobalResourceName) -and ($GLOBAL:GlobalResourceName -ne '')){
                $StartOfMessage = $TextType + ' [' + $GLOBAL:GlobalResourceName + ']:'
            }
            else {
                $StartOfMessage = $TextType
            }

            # make sure left_column is a certain length
            while ($StartOfMessage.length -lt $LoggingOptions.left_column_width) {
                $StartOfMessage = $StartOfMessage + ' '
            }

            if (($null -ne $GLOBAL:GlobalActionName) -and ($GLOBAL:GlobalActionName -ne '')){
                if ($null -ne $GLOBAL:GlobalPhase) {
                $StartOfMessage += '[' + $GLOBAL:GlobalActionName + '][' +  $GLOBAL:GlobalPhase  +'] '
                }
                else {
                    $StartOfMessage += '[' + $GLOBAL:GlobalActionName + '] '
                }
            }
            # determine the console width
            if ($LoggingOptions.force_console_width) {
                $ConsoleWidth = $LoggingOptions.force_console_width
            }
            else {
                $ConsoleWidth = $Host.UI.RawUI.WindowSize.Width
            }

            if ($DisplayLocation) {
                $TargetMessageLength = $ConsoleWidth - ($LoggingOptions.post_buffer + $StartOfMessage.Length + $LocationString.Length)
            }
            else {
                $TargetMessageLength = $ConsoleWidth - ($LoggingOptions.post_buffer + $StartOfMessage.Length)
            }

            if ($Header) {
                # Get-DryHeader will call Out-DryLog back after making a header
                $HeaderLine,$Message = Get-DryHeader -Message $Message -TargetMessageLength $TargetMessageLength -HeaderChars $HeaderChars -Air:$Air
            }
            elseif ($SmallHeader) {
                $Message = Get-DryHeader -Message $Message -Small -TargetMessageLength $TargetMessageLength -HeaderChars $HeaderChars -Air:$Air
            }

            if ($PSCmdlet.ParameterSetName -eq 'message') {
                if ($Type -in @('success','fail')) {
                    do {
                        $StatusText = "$StatusText "
                    }
                    while ($StatusText.length -le $LoggingOptions.array_first_element_length)
                    $Messages = @("$StatusText`: $Message")
                }
                # If $TargetMessageLength is greater than the $LoggingOptions.console_width_threshold, and
                # $Message is longer than $TargetMessageLength, we want to split the message
                # into chunks so they fit nicely in the console
                elseif (
                    ($TargetMessageLength -gt $LoggingOptions.console_width_threshold) -and
                    ($Message.Length -gt $TargetMessageLength)
                ) {
                    [Array]$Messages = Split-DryString -Length $TargetMessageLength -String $Message
                }
                else {
                    if ($HeaderLine) {
                        [Array]$Messages += $HeaderLine
                    }
                    [Array]$Messages += $Message
                }
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'hashtable') {
                # hashtable - loop through all key-value pairs
                if ($MsgTitle) {
                    $NestedOutDryLogCallParams += @{
                        Message         = "$MsgTitle"
                        Type            = $Type
                        Callstacklevel  = $($Callstacklevel + 1) 
                        Smallheader     = $true
                    }
                    Out-DryLog @NestedOutDryLogCallParams
                }
                $Messages = @()
                #! Skrives om til å gjøre et nested call 
                foreach ($Key in $MsgHash.Keys) {
                    Remove-Variable -Name ThisValue -ErrorAction Ignore
                    if ($($MsgHash[$Key]) -is [PSCredential]) {
                        if ($GLOBAL:dry_var_global_ShowPasswords) {
                            $ThisValue = ($MsgHash[$Key]).UserName + '===>' + ($MsgHash[$Key]).GetNetworkCredential().Password
                        }
                        else {
                            $ThisValue = ($MsgHash[$Key]).UserName
                        }
                    }
                    else {
                        if ($Key -match "password") {
                            do {
                                $ThisValue = "$ThisValue*"
                            }
                            until ($ThisValue.Length -ge ($MsgHash[$Key]).Length)
                        }
                        else {
                            $ThisValue = $MsgHash[$Key]
                        }
                    }
                    $Messages += "'$Key" + '=' + $ThisValue + "'"
                }
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'array') {
                $FirstElement = $MsgArr[0]
                $SecondElement = $MsgArr[1]
                $BlankFirstElement = ''
                $ArrayMessages = $null
                $ArrayMessage = $null

                do {
                    $FirstElement = "$FirstElement "
                }
                while ($FirstElement.length -le $LoggingOptions.array_first_element_length)
                do {
                    $BlankFirstElement = "$BlankFirstElement "
                }
                while ($BlankFirstElement.length -le $LoggingOptions.array_first_element_length)
                $ArrayMessage = "$($FirstElement): $($SecondElement)"
                
                if (($TargetMessageLength -gt $LoggingOptions.console_width_threshold) -and
                    ($ArrayMessage.Length -gt $TargetMessageLength)) {
                    $ArrayMessages = $null
                    [Array]$ArrayMessages = Split-DryString -Length ($TargetMessageLength - ("$($FirstElement): ").length ) -String $SecondElement
                    
                    switch ($ArrayMessages.count) {
                        {$_ -eq 1 } {
                            [System.Collections.Generic.List[String]]$Messages = @("$($ArrayMessages[0])")
                        }
                        {$_ -gt 1 } {
                            [System.Collections.Generic.List[String]]$Messages = @("$($FirstElement): $($ArrayMessages[0])")
                            for ($m = 1; $m -le $ArrayMessages.count; $m++) {
                                $Messages.Add("$($BlankFirstElement)  $($ArrayMessages[$m])")
                            }
                        }
                    }
                }
                else {
                    [System.Collections.Generic.List[String]]$Messages = @("$ArrayMessage")
                }                
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'object') {
                # The header (name of object)
                if ($MsgTitle) {
                    $NestedOutDryLogCallParams += @{
                        Message         = "$MsgTitle"
                        Type            = $Type
                        Callstacklevel  = $($Callstacklevel + 1) 
                        Smallheader     = $true
                    }
                    if ($LOFore) {
                        $NestedOutDryLogCallParams += @{
                            foregroundcolor = $LOFore
                        }
                    }
                    if ($LOBack) {
                        $NestedOutDryLogCallParams += @{
                            backgroundcolor = $LOBack
                        }
                    }
                    Out-DryLog @NestedOutDryLogCallParams
                }

                # Iterate through properties
                $MsgObj.PSObject.Properties | foreach-Object {
                    #Write-Host "Value type $(($_.Value).Gettype().Name)"
                    if ($null -eq $_.Value) { $_.Value = '(null)'}
                    if (($_.Value -is [string]) -or ($_.Value -is [bool]) -or (($_.Value).Gettype().Name -match 'byte|short|int32|long|sbyte|ushort|uint32|ulong|float|double|decimal|Version')) {
                        $NestedOutDryLogCallParams = @{
                            Type            = $Type
                            MsgArr          = @(($(' '*$MsgObjLevel + ' ') + ($_.Name)),$_.Value) 
                            Callstacklevel  = $Callstacklevel+1
                        }
                        if ($LOFore) {
                            $NestedOutDryLogCallParams += @{
                                foregroundcolor = $LOFore
                            }
                        }
                        if ($LOBack) {
                            $NestedOutDryLogCallParams += @{
                                backgroundcolor = $LOBack
                            }
                        }
                        Out-DryLog @NestedOutDryLogCallParams
                    }
                    elseif ($_.Value -is [Array]) {
                        $ObjValue = $_.Value
                        $ObjName = $_.Name
                        $NestedOutDryLogCallParams = @{
                            Type            = $Type
                            Message         = ($(' '*$MsgObjLevel+ ' ') + "$ObjName") 
                            Callstacklevel  = $Callstacklevel+1
                        }
                        if ($LOFore) {
                            $NestedOutDryLogCallParams += @{
                                foregroundcolor = $LOFore
                            }
                        }
                        if ($LOBack) {
                            $NestedOutDryLogCallParams += @{
                                backgroundcolor = $LOBack
                            }
                        }
                        Out-DryLog @NestedOutDryLogCallParams  
                        foreach ($ObjItem in $ObjValue) {
                            if (($ObjItem -is [string]) -or ($ObjItem -is [bool]) -or ($ObjItem.Gettype().Name -match 'byte|short|int32|long|sbyte|ushort|uint32|ulong|float|double|decimal|Version')) {
                                $NestedOutDryLogCallParams = @{
                                    Type            = $Type
                                    Message         = ($('  '*$MsgObjLevel+ ' ') + "$ObjItem")
                                    Callstacklevel  = $Callstacklevel+1
                                }
                                if ($LOFore) {
                                    $NestedOutDryLogCallParams += @{
                                        foregroundcolor = $LOFore
                                    }
                                }
                                if ($LOBack) {
                                    $NestedOutDryLogCallParams += @{
                                        backgroundcolor = $LOBack
                                    }
                                }
                                Out-DryLog @NestedOutDryLogCallParams
                            }
                            elseif ($ObjItem -is [PSCustomObject]) {
                                $NestedOutDryLogCallParams = @{
                                    Type            = $Type
                                    MsgObj          = $ObjItem 
                                    Callstacklevel  = $Callstacklevel+1
                                    MsgObjLevel     = $MsgObjLevel+1
                                }
                                if ($LOFore) {
                                    $NestedOutDryLogCallParams += @{
                                        foregroundcolor = $LOFore
                                    }
                                }
                                if ($LOBack) {
                                    $NestedOutDryLogCallParams += @{
                                        backgroundcolor = $LOBack
                                    }
                                }
                                Out-DryLog @NestedOutDryLogCallParams
                            }
                        }
                    } 
                    elseif ($_.Value -is [PSCustomObject]) {
                        $NestedOutDryLogCallParams = @{
                            Type            = $Type
                            MsgObj          = $_.Name 
                            Callstacklevel  = $Callstacklevel+1
                            MsgObjLevel     = $MsgObjLevel+1
                        }
                        if ($LOFore) {
                            $NestedOutDryLogCallParams += @{
                                foregroundcolor = $LOFore
                            }
                        }
                        if ($LOBack) {
                            $NestedOutDryLogCallParams += @{
                                backgroundcolor = $LOBack
                            }
                        }
                        Out-DryLog @NestedOutDryLogCallParams
                        Out-DryLog -Type $Type -MsgObj $_.Name -Callstacklevel $($Callstacklevel+1) -MsgObjLevel $($MsgObjLevel+1)
                        Out-DryLog -Type $Type -MsgObj $_.Value -Callstacklevel $($Callstacklevel+1) -MsgObjLevel $($MsgObjLevel+1)
                    }
                }
            }

            foreach ($MessageChunk in $Messages) {
                do {
                    $MessageChunk = "$MessageChunk "
                }
                while ($MessageChunk.length -le $TargetMessageLength)

                # Attach the pieces
                if ($DisplayLocation) {
                    $FullMessageChunk = $StartOfMessage + $MessageChunk + $LocationString
                }
                else {
                    $FullMessageChunk = $StartOfMessage + $MessageChunk
                }

                if ($LogColors) {
                    Write-Host @LogColors -Object $FullMessageChunk
                }
                else {
                    Write-Host -Object $FullMessageChunk
                }
            }
        }

        # Log to file
        switch ($LoggingOptions.log_to_file) {
            $True {
                switch ($PSCmdlet.ParameterSetName) {
                    'message' {
                        if (-not $Header) {
                            $LogMessage = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($StartOfMessage + ": " + $Message), $Location, (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $PID
                            $LogMessage | Out-File -Append -Encoding UTF8 -FilePath ("filesystem::{0}" -f $LogFile) -Force
                        }
                    }
                    'hashtable' {
                        foreach ($Key in $MsgHash.Keys) {
                            $LogMessage = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($StartOfMessage + ": " + $Key + '=' + $MsgHash[$Key] ), $Location, (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $PID
                            $LogMessage | Out-File -Append -Encoding UTF8 -FilePath ("filesystem::{0}" -f $LogFile) -Force
                        }
                    }
                    'array' {
                        $LogMessage = "{0} `$$<{1}><{2} {3}><thread={4}>" -f ($StartOfMessage + ": " + $MsgArr[0] + ' => ' + $MsgArr[1] ), $Location, (Get-Date -Format "MM-dd-yyyy"), (Get-Date -Format "HH:mm:ss.ffffff"), $PID
                        $LogMessage | Out-File -Append -Encoding UTF8 -FilePath ("filesystem::{0}" -f $LogFile) -Force
                    }
                }
            }
            default {
                # do nothing
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}