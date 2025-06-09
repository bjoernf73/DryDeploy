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

function Get-DryHeader{
    [CmdletBinding(DefaultParameterSetName="multilineheader")]
    [OutputType([array],ParameterSetName="multilineheader")]
    [OutputType([string],ParameterSetName="singlelineheader")]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Message,

        [Parameter(HelpMessage="Number of whitespaces on the right side of screen, after each message line")]
        [int]$PostBuffer = 3,

        [Parameter(HelpMessage="A sequence of characters of a specific length")]
        [string]$HeaderChars = '.',

        [Alias("sh")]
        [Parameter(Mandatory,ParameterSetName="singlelineheader",HelpMessage="Get a smaller, one-line header")]
        [Switch]$Small,

        [Parameter(HelpMessage="Converts 'Message' to 'M e s s a g e'")]
        [Switch]$Air,

        [Parameter(Mandatory,ParameterSetName="singlelineheader")]
        [Parameter(Mandatory,ParameterSetName="multilineheader")]
        [int]$TargetMessageLength
    )

    # Make an array of the header chars
    for ($hca = 0; $hca -lt $HeaderChars.length; $hca++){
        [array]$HeaderCharsArray += $HeaderChars[$hca]
    }

    # Converts 'Message' to 'M e s s a g e'
    if($Air){
        $AiredMessage = ''
        for ($LetterCount = 0; $LetterCount -lt $Message.Length; $LetterCount++){
            $AiredMessage += $Message.SubString($LetterCount,1)
            $AiredMessage = "$AiredMessage "
        }
        $Message = $AiredMessage
    }

    switch($PSCmdlet.ParameterSetName){
        'singlelineheader'{
            # add $PostBuffer
            for ($b = 0; $b -lt $PostBuffer; $b++){
                $Message = "$Message "
            }

            # Determine which of the elements in the array to start on - this is to make HeaderChars aligned
            $HeaderCharIndex = ($Message.length)%($HeaderCharsArray.length)

            while ($Message.Length -lt $TargetMessageLength){
                $Message = $Message + $HeaderCharsArray[$HeaderCharIndex]
                $HeaderCharIndex++
                if($HeaderCharIndex -gt ($HeaderCharsArray.length-1)){
                    $HeaderCharIndex = 0
                }
            }
            $Message
         }
        'multilineheader'{
            # Just output the header line
            [string]$HeaderLine = ''
            $HeaderCharIndex = 0
            while ($HeaderLine.Length -lt $TargetMessageLength){
                $HeaderLine = $HeaderLine + $HeaderCharsArray[$HeaderCharIndex]
                $HeaderCharIndex++
                if($HeaderCharIndex -gt ($HeaderCharsArray.length-1)){
                    $HeaderCharIndex = 0
                }
            }
            #  Output the header line and message
            $HeaderLine,$Message
        }
    }
}