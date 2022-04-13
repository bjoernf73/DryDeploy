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


function Get-DryReplacementHash {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSObject[]]$ConfigurationSet,

        [Parameter(HelpMessage="Not in use by the function, but may be used by expressions that resolve the replacement pattern values")]
        [PSObject]$Configuration,

        [Parameter(HelpMessage="Hashtable to add the contents to. I will return a new hashtable including the ReplacementHash, but not modify the original ReplacementHash")]
        [hashtable]$ReplacementHash,

        [Parameter()]
        [PSObject]$Resource,

        [Parameter()]
        [String]$ADSite
    )
    
    if ($ReplacementHash) {
        $PRIVATE:PrivateReplacementHash = $ReplacementHash.PsObject.Copy()
    } 
    else {
        [HashTable]$PRIVATE:PrivateReplacementHash = @{}
    }
    
    foreach ($ReplacementPattern in $ConfigurationSet) {
        
        # The expression to extract the replacement value may require modules that are 'using'
        # other modules, so those modules must be excplicitly loaded before execution
        if ($ReplacementPattern.required_modules) {
            ol v "ReplacementPattern requires external modules to be installed"

            foreach ($RequiredModule in $ReplacementPattern.required_modules) {
                if ((Get-Module).Name -notcontains $RequiredModule) {
                    ol v "Importing module '$RequiredModule' into session"
                    Import-Module -Name $RequiredModule -Verbose:$False -ErrorAction Stop
                }
            }
        }
        
        # ReplacementPattern values can be a string, expression or a variable
        switch ($ReplacementPattern.value_type) {
            'expression' {
                # The ReplacementPattern value is an expression
                try {
                    $PatternValue = Invoke-Expression -Command $ReplacementPattern.value
                    if (($null -eq $PatternValue) -or ($PatternValue -eq '')) {
                        throw "Resolved empty value for pattern '$($ReplacementPattern.name)'"
                    }
                }
                catch {
                    ol e "Error executing ReplacementPattern expression for: '$($ReplacementPattern.name)', expression: '$($ReplacementPattern.value)'"
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            'variable' {
                try {
                    $PatternValue = (Get-Variable -Name $(($ReplacementPattern.value).Trimstart('$')) -ErrorAction 'Stop').Value
                    if (($null -eq $PatternValue) -or ($PatternValue -eq '')) {
                        throw "Resolved empty value for pattern '$($ReplacementPattern.name)'"
                    }
                }
                catch {
                    ol e "Error getting ReplacementPattern variable for: '$($ReplacementPattern.name)', variable: '$($ReplacementPattern.value)'"
                    $PSCmdlet.ThrowTerminatingError($_)
                }  
            }
            'string' {
                # The ReplacementPattern value is a string
                try {
                    $PatternValue = $ReplacementPattern.value
                    if (($Null -eq $PatternValue) -or ($PatternValue -eq '')) {
                        throw "Resolved empty value for pattern '$($ReplacementPattern.name)'"
                    }
                }
                catch {
                    ol e "Error getting ReplacementPattern string for: '$($ReplacementPattern.name)', string: '$($ReplacementPattern.value)'"
                    $PSCmdlet.ThrowTerminatingError($_)
                }  
            }
        }
        
        ol v "Creating ReplacementPattern: '$($ReplacementPattern.name)', value: '$($PatternValue)'"
        $PrivateReplacementHash.Add($ReplacementPattern.name,$PatternValue)
    }
    $PrivateReplacementHash
}