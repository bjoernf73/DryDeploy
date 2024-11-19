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

function Split-DryString {
    param (
        [Parameter(Mandatory,HelpMessage="The string to split into chunks of a certain maximum length")]
        [ValidateNotNullOrEmpty()]
        [string]
        $String,

        [Parameter(Mandatory,HelpMessage="The function will split `$String into an array of strings, or
        chunks, of maximum length `$Length. They may be shorter - see description of paramameter
        `$WhiteSpaceAtEndChars below")]
        [ValidateScript({"$_ -gt 1"})]
        [int]
        $Length,

        [Parameter(HelpMessage="In order not to split a sentence in the middle of a word, the function
        will search the last 10 (or, the number of `$WhiteSpaceAtEndChars) chars, of each chunk, for a
        whitespace. If a whitespace is found within those chars, it will split at the whitespace instead
        of exactly at `$Length")]
        [int]
        $WhiteSpaceAtEndChars = 10
    )

    $Chunks = @()
    $i = 0

    # Replace tabs with whitespace
    $String = $String.Replace("`t"," ")

    while ($i -le ($String.length-$Length)){
        $Chunk = $String.Substring($i,$Length)
        # Search for the last whitespace in the $WhiteSpaceAtEndChars number of
        # characters at the end of each chunk. But only if all of the following
        # conditions are met:
        #  - the chunk is of the full length
        #  - the charachter following the chunk is not a whitespace
        #  - the last character of the chunk is not a whitespace
        # If such a whitespace is found, we split at that instead
        if ($String.Length -gt ($i+$Chunk.Length+1) ) {
            if ( ($Chunk.Length -eq $Length) -and ( $String.Substring($i+$Chunk.Length,1) -ne ' ') -and ( $Chunk.Substring($Chunk.Length-1) -ne ' ') ) {
                $LastWhiteSpace = ($Chunk.Substring($Chunk.Length-$WhiteSpaceAtEndChars)).LastIndexOf(' ')
                if ($LastWhiteSpace -ge 0) {
                    $cutindex = $WhiteSpaceAtEndChars - ($LastWhiteSpace+1)
                    $Chunks += ($String.Substring($i,$Length-$cutindex)).Trim()
                    $i += $Length-$cutindex
                }
                else {
                    # No Whitespace found
                    $Chunks += ($String.Substring($i,$Length)).Trim()
                    $i += $Length
                }
            }
            else {
                # Just add to chunks and add $Length to $i
                $Chunks += ($String.Substring($i,$Length)).Trim()
                $i += $Length
            }
        }
        else {
            $Chunks += ($String.Substring($i,$Length)).Trim()
            $i += $Length
        }
    }
    if (($String.Substring($i)).Trim() -ne '') {
        $Chunks += $String.Substring($i)
    }
    $Chunks
}