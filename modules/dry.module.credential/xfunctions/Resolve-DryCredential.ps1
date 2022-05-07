<#
 This module handles credentials for DryDeploy

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.credential/main/LICENSE
 
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

function Resolve-DryCredential {
    [CmdletBinding()]
    param (
        [Parameter(ParametersetName="InputObject",Mandatory,HelpMessage="Expects an object of in which one or more property values matches the the replacement string '___cred___*___'")]
        [PSCustomObject]$InputObject,

        [ValidatePattern("___cred___.*___")]
        [Parameter(ParametersetName="InputString",Mandatory,HelpMessage="Expects a string matching one of the replacement strings")]
        [String]$InputString
    )
    
    try {
        if ($InputObject) {
            # make a copy of the object, or else the changes 
            # may be written back to the original object
            $CopyObject = $InputObject.PSObject.Copy()
            # loop through all properties of $InputObject
            $CopyObject.PSObject.Properties | 
                Foreach-Object {
                $PropertyName = $_.Name
                $PropertyValue = $_.Value
                # If Key is a string, we can do the replacement. If it is an
                # object, we must make a nested call. If array, make nested
                # call for each element of the array
                if (($PropertyValue -is [String]) -and ($PropertyValue -match "___cred___.*___")) {
                    # Call Resolve-DryPassword that returns the replaced string
                    $PropertyValue = Resolve-DryCredential -InputString $PropertyValue  
                }
                elseif ($PropertyValue -is [PSObject]) {
                    # make a nested call to this function
                    $PropertyValue = Resolve-DryCredential -InputObject $PropertyValue 
                } 
                elseif ($PropertyValue -is [Array]) {
                    # nested call for each array element
                    $PropertyValue = @(  $PropertyValue | Foreach-Object { 
                        if (($_ -is [String]) -and ($_ -match "___cred___.*___")) {
                            Resolve-DryCredential -InputText $_ 
                        } 
                        elseif (($_ -is [String]) -and ($_ -notmatch "___cred___.*___")) {
                            # just return the original object
                            $_
                        }
                        else {
                            Resolve-DryCredential -InputObject $_ 
                        }
                    })
                }
                $CopyObject."$PropertyName" = $PropertyValue
            }
            return $CopyObject
        } 
        else {
            # Get the credential alias which is <name> in '___pwd___<name>___'
            $CredentialName = $InputString.Substring(10,($InputString.length-13))
            $CredObject = Get-DryCredential -Alias $CredentialName -EnvConfig $GLOBAL:dry_var_global_ConfigCombo.envconfig.name
            $CredObject
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}