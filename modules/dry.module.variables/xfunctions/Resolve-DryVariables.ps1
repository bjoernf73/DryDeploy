<# 
 This module provides functions to resolve values from expressions for use with DryDeploy.

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

function Resolve-DryVariables {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,HelpMessage="The variables to resolve. The variables may be expressions that resolves environment specific values by referencing
        the environment configuration (`$Configuration), the resource object (`$Resource), the action object (`$Action), or any other variable in a scope available
        inside the function (for instance the global scope)")]
        [PSObject[]]$Variables,

        [Parameter(HelpMessage="If given, the variables list will be attached to the returned object")]
        [System.Collections.Generic.List[PSObject]]$VariablesList,

        [Parameter(HelpMessage="The resolved action object. Not in use by the function, but may be used by expressions that resolves a value")]
        [PSObject]
        $Action,

        [Parameter(HelpMessage="The resolved resource object. Not in use by the function, but may be used by expressions that resolves a value")]
        [PSObject]
        $Resource,

        [Parameter(HelpMessage="The resolved credentials list for the action. Not in use by the function, but may be used by expressions that resolves a value")]
        [PSCustomObject]
        $Credentials,

        [Parameter(HelpMessage="The resolved environment configuration object. Not in use by the function, but may be used by expressions that resolves a value")]
        [PSObject]
        $Configuration,

        [Parameter(HelpMessage="Resolved Paths ++ from Resolve-DryActionOptions. Not in use by the function, but may be used by expressions that resolves a value")]
        [PSObject]
        $Resolved,

        [Parameter(Helpmessage="Specify the output you want, either 'hashtable' or 'list'. Defaults to 'list'")]
        [ValidateSet('hashtable', 'list')]
        [String]$OutPutType = 'list'
    )
    try {
        Switch ($OutPutType) {
            'hashtable' {
                $PRIVATE:PrivateVariablesHash = [HashTable]::New()
            }
            'list' {
                $PRIVATE:PrivateVariablesList = [System.Collections.Generic.List[PSObject]]::New()
            }
        }
    
        # $VariablesList is an optional list of existing variables that will bundled together with the resolved $Variables
        if ($VariablesList) {
            foreach ($Var in $VariablesList) { 
                Remove-Variable -Name VarCopy -ErrorAction Ignore -Scope Local
                $VarCopy = $Var.PSObject.Copy()
                $PrivateVariablesList.Add($VarCopy)

                # Create the variable in the local scope, so subsequent expressions can use previously resolved variable values
                if (Get-Variable -Name $VarCopy.Name -Scope Local -ErrorAction Ignore) {
                    Set-Variable -Name $VarCopy.Name -Value $VarCopy.Value -Scope Local
                }
                else {
                    New-Variable -Name $VarCopy.Name -Value $VarCopy.Value -Scope Local  
                }
            }
        }    

        ForEach ($Var in $Variables) {
            Remove-Variable -name VarValue -ErrorAction Ignore
            Switch ($Var.value_type) {
                'expression' {
                    Try {
                        Remove-Variable -name VarValue -ErrorAction Ignore
                        Switch ($Var.parameter_type) {
                            'PSCredential' {
                                [PSCredential]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                            'Array' {
                                [Array]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                            'Int' {
                                [Int]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                            {$_ -in @('bool','boolean')} {
                                [bool]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                            'String' {
                                [String]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                            {$_ -in @('PSObject','PSCustomObject')} {
                                [PSCustomObject]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                            Default {
                                # Accept whatever type is returned
                                $VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                        }
                    }
                    Catch {
                        ol e "Error executing variable expression for: '$($Var.name)', expression: '$($Var.value)'"
                        $PSCmdlet.ThrowTerminatingError($_)
                    }  
                }
                {$_ -in @('string','int')} {
                    Switch ($Var.parameter_type) {
                        'Array' {
                            [Array]$VarValue = $Var.value 
                        }
                        'Int' {
                            [Int]$VarValue = $Var.value 
                        }
                        {$_ -in @('bool','boolean')} {
                            [bool]$VarValue = $Var.value 
                        }
                        'String' {
                            [String]$VarValue = $Var.value 
                        }
                        Default {
                            # Accept whatever type is returned
                            $VarValue = $Var.value
                        }
                    }
                }
                {$_ -in 'bool','boolean'} {
                    # The variable value is a boolean
                    Try {
                        [Boolean]$VarValue = $Var.Value
                        Switch ($Var.parameter_type) {
                            'Array' {
                                [Array]$VarValue = @($Var.value)
                            }
                            'Int' {
                                [Int]$VarValue = $Var.value 
                            }
                            'String' {
                                [String]$VarValue = ($Var.value).ToString()
                            }
                            Default {
                                # Accept whatever type is returned
                                $VarValue = $Var.value
                            }
                        }
                    }
                    Catch {
                        ol e "Error converting '$($Var.name)' to boolean. The value was '$($Var.value)'"
                        $PSCmdlet.ThrowTerminatingError($_)
                    }  
                }
                'function' {
                    # The variable value is a function call
                    Try {
                        Remove-Variable -name VarValue,FunctionParamsHash,FunctionParamsNameArr,FunctionParamsName -ErrorAction Ignore
                        $FunctionParamsHash = [HashTable]::New()
                        $FunctionParamsNameArr = @($Var.parameters | Get-Member -MemberType NoteProperty | Select-Object -Property Name).Name
                        
                        ForEach ($FunctionParamsName in $FunctionParamsNameArr) {
                            # First, value of $Var.parameters."$FunctionParamsName" is now string like '$Resource' and not a variable representing the object $Resource. 
                            # Fix that by invoking the string
                            $Var.parameters."$FunctionParamsName" = Invoke-Expression -Command ($Var.parameters."$FunctionParamsName") -Erroraction 'Stop'
                            
                            # Add the key value pair to hash, so we can @splat
                            $FunctionParamsHash+= @{ $FunctionParamsName = $Var.parameters."$FunctionParamsName" }
                        }
                    
                        Switch ($Var.parameter_type) {
                            'PSCredential' {
                                [PSCredential]$VarValue = & $Var.function @FunctionParamsHash
                            }
                            'Array' {
                                [Array]$VarValue = & $Var.function @FunctionParamsHash
                            }
                            'Int' {
                                [Int]$VarValue = & $Var.function @FunctionParamsHash
                            }
                            {$_ -in @('bool','boolean')} {
                                [bool]$VarValue = & $Var.function @FunctionParamsHash
                            }
                            'String' {
                                [String]$VarValue = & $Var.function @FunctionParamsHash
                            }
                            {$_ -in @('PSObject','PSCustomObject')} {
                                [PSCustomObject]$VarValue = & $Var.function @FunctionParamsHash
                            }
                            Default {
                                # Accept whatever type is returned
                                $VarValue = & $Var.function @FunctionParamsHash
                            }
                        } 
                    }
                    Catch {
                        ol e "Error executing variable expression for: '$($Var.name)', expression: '$($Var.value)'"
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }
            }
            # fail if it's null, unless property allow_null allows it
            if (($null -eq $VarValue) -and ($Var.allow_null -eq $true)) {
                ol e 'Variable resolved null',"$($Var.Name)"
                throw "Variable '$($Var.Name)' resolved null"
            }

            # Create the variable in the local scope, so subsequent expressions can use previously resolved variable values
            if (Get-Variable -Name $Var.Name -Scope Local -ErrorAction Ignore) {
                Set-Variable -Name $Var.Name -Value $VarValue -Scope Local
            }
            else {
                New-Variable -Name $Var.Name -Value $VarValue -Scope Local  
            }

            # Add value to the correct output object
            Switch ($OutPutType) {
                'hashtable' {
                    $PrivateVariablesHash += @{$Var.Name = $VarValue}
                }
                'list' {
                    $Secret = $false
                    if ($true -eq $Var.secret) {
                        $Secret = $true
                    }
                    $PrivateVariablesList.Add([PSCustomObject]@{
                        Name   = $Var.Name
                        Value  = $VarValue
                        Secret = $Secret
                    })
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
    }
 
    Switch ($OutPutType) {
        'hashtable' {
            return $PrivateVariablesHash
        }
        'list' {
            return $PrivateVariablesList
        }
    }
}