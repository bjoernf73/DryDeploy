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

function Resolve-DryVariables{
    [CmdletBinding()]
    param(
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
        [string]$OutPutType = 'list'
    )
    try{
        switch($OutPutType){
            'hashtable'{
                $PRIVATE:PrivateVariablesHash = [hashtable]::New()
            }
            'list'{
                $PRIVATE:PrivateVariablesList = [System.Collections.Generic.List[PSObject]]::New()
            }
        }
    
        # $VariablesList is an optional list of existing variables that will bundled together with the resolved $Variables
        if($VariablesList){
            foreach($Var in $VariablesList){ 
                Remove-Variable -Name VarCopy -ErrorAction Ignore -Scope Local
                $VarCopy = $Var.PSObject.Copy()
                $PrivateVariablesList.Add($VarCopy)

                # Create the variable in the local scope, so subsequent expressions can use previously resolved variable values
                if(Get-Variable -Name $VarCopy.Name -Scope Local -ErrorAction Ignore){
                    Set-Variable -Name $VarCopy.Name -Value $VarCopy.Value -Scope Local
                }
                else{
                    New-Variable -Name $VarCopy.Name -Value $VarCopy.Value -Scope Local  
                }
            }
        }    

        foreach($Var in $Variables){
            Remove-Variable -name VarValue -ErrorAction Ignore
            switch($Var.value_type){
                'expression'{
                    try{
                        Remove-Variable -name VarValue -ErrorAction Ignore
                        switch($Var.parameter_type){
                            'PSCredential'{
                                [PSCredential]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                            'Array'{
                                [array]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                            'Int'{
                                [int]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                           {$_ -in @('bool','boolean')}{
                                [bool]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                            'String'{
                                [string]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                           {$_ -in @('PSObject','PSCustomObject')}{
                                [PSCustomObject]$VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                            default{
                                # Accept whatever type is returned
                                $VarValue = Invoke-Expression -Command $Var.value -ErrorAction Stop
                            }
                        }
                    }
                    catch{
                        ol e "Error executing variable expression for: '$($Var.name)', expression: '$($Var.value)'"
                        $PSCmdlet.ThrowTerminatingError($_)
                    }  
                }
               {$_ -in @('string','int')}{
                    switch($Var.parameter_type){
                        'Array'{
                            [array]$VarValue = $Var.value 
                        }
                        'Int'{
                            [int]$VarValue = $Var.value 
                        }
                       {$_ -in @('bool','boolean')}{
                            [bool]$VarValue = $Var.value 
                        }
                        'String'{
                            [string]$VarValue = $Var.value 
                        }
                        default{
                            # Accept whatever type is returned
                            $VarValue = $Var.value
                        }
                    }
                }
               {$_ -in 'bool','boolean'}{
                    # The variable value is a boolean
                    try{
                        [Boolean]$VarValue = $Var.Value
                        switch($Var.parameter_type){
                            'Array'{
                                [array]$VarValue = @($Var.value)
                            }
                            'Int'{
                                [int]$VarValue = $Var.value 
                            }
                            'String'{
                                [string]$VarValue = ($Var.value).ToString()
                            }
                            default{
                                # Accept whatever type is returned
                                $VarValue = $Var.value
                            }
                        }
                    }
                    catch{
                        ol e "Error converting '$($Var.name)' to boolean. The value was '$($Var.value)'"
                        $PSCmdlet.ThrowTerminatingError($_)
                    }  
                }
                'function'{
                    # The variable value is a function call
                    try{
                        Remove-Variable -name VarValue,FunctionParamsHash,FunctionParamsNameArr,FunctionParamsName -ErrorAction Ignore
                        $FunctionParamsHash = [hashtable]::New()
                        $FunctionParamsNameArr = @($Var.parameters | Get-Member -MemberType NoteProperty | Select-Object -Property Name).Name
                        
                        foreach($FunctionParamsName in $FunctionParamsNameArr){
                            # First, value of $Var.parameters."$FunctionParamsName" is now string like '$Resource' and not a variable representing the object $Resource. 
                            # Fix that by invoking the string
                            $Var.parameters."$FunctionParamsName" = Invoke-Expression -Command ($Var.parameters."$FunctionParamsName") -Erroraction 'Stop'
                            
                            # Add the key value pair to hash, so we can @splat
                            $FunctionParamsHash+= @{ $FunctionParamsName = $Var.parameters."$FunctionParamsName" }
                        }
                    
                        switch($Var.parameter_type){
                            'PSCredential'{
                                [PSCredential]$VarValue = & $Var.function @FunctionParamsHash
                            }
                            'Array'{
                                [array]$VarValue = & $Var.function @FunctionParamsHash
                            }
                            'Int'{
                                [int]$VarValue = & $Var.function @FunctionParamsHash
                            }
                           {$_ -in @('bool','boolean')}{
                                [bool]$VarValue = & $Var.function @FunctionParamsHash
                            }
                            'String'{
                                [string]$VarValue = & $Var.function @FunctionParamsHash
                            }
                           {$_ -in @('PSObject','PSCustomObject')}{
                                [PSCustomObject]$VarValue = & $Var.function @FunctionParamsHash
                            }
                            default{
                                # Accept whatever type is returned
                                $VarValue = & $Var.function @FunctionParamsHash
                            }
                        } 
                    }
                    catch{
                        ol e "Error executing variable expression for: '$($Var.name)', expression: '$($Var.value)'"
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }
            }
            # fail if it's null, unless property allow_null allows it
            if(($null -eq $VarValue) -and ($Var.allow_null -ne $true)){
                ol e 'Variable resolved null',"$($Var.Name)"
                throw "Variable '$($Var.Name)' resolved null"
            }

            # fail if it's a string and it's trimmed value is an empty string, unless allow_null allows it
            if($VarValue -is [string]){
                if($VarValue.trim() -eq ''){
                    if($Var.allow_null){
                        ol w 'Variable resolved empty string, but allowed',"$($Var.Name) (string)"
                    }
                    else{
                        ol e 'Variable resolved empty string',"$($Var.Name) (string)"
                        throw "Variable '$($Var.Name)' resolved empty string"
                    }
                }
            }

            # fail if it's an array with no elements, unless allow_null allows it
            if($VarValue -is [array]){
                if($VarValue.count -eq 0){
                    if($Var.allow_null){
                        ol w 'Variable resolved 0 elements, but allowed',"$($Var.Name) (array)"
                    }
                    else{
                        ol e 'Variable resolved 0 array elements',"$($Var.Name) (array)"
                        throw "Variable '$($Var.Name)' resolved 0 array elements"
                    }
                }
            }

            # Create the variable in the local scope, so subsequent expressions can use previously resolved variable values
            if(Get-Variable -Name $Var.Name -Scope Local -ErrorAction Ignore){
                Set-Variable -Name $Var.Name -Value $VarValue -Scope Local
            }
            else{
                New-Variable -Name $Var.Name -Value $VarValue -Scope Local  
            }

            # Add value to the correct output object
            switch($OutPutType){
                'hashtable'{
                    $PrivateVariablesHash += @{$Var.Name = $VarValue}
                }
                'list'{
                    $Secret = $false
                    if($true -eq $Var.secret){
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
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
    }
 
    switch($OutPutType){
        'hashtable'{
            return $PrivateVariablesHash
        }
        'list'{
            return $PrivateVariablesList
        }
    }
}