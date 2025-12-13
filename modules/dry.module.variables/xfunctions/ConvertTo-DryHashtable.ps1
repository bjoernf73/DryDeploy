<# 
 This module provides functions to resolve values from expressions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function ConvertTo-DryHashtable{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,HelpMessage="The variables to convert. Only the 'name' and 'value' properties will be preserved
        in the returned hashtable")]
        [PSObject[]]$Variables,

        [Parameter(HelpMessage="Variables may have a property 'secret'. If `$NotSecrets is true, and 'secret' is also true, 
        that variable will not be included in the resulting hashtable")]
        [Switch]$NotSecrets,

        [Parameter(HelpMessage="Variables may have a property 'secret'. If `$OnlySecrets is true, only variables who's property 
        'secret' equals true will be included in the returned hashtable")]
        [Switch]$OnlySecrets
    )
    try{
        $PRIVATE:PrivateVariablesHash = $null
        $PRIVATE:PrivateVariablesHash = [hashtable]::New()
        foreach($Var in $Variables){
            if($NotSecrets){
                if($Var.Secret -ne $true){
                    $PRIVATE:PrivateVariablesHash += @{$Var.Name = $Var.Value}
                }
            }
            elseif($OnlySecrets){
                if($Var.Secret -eq $true){
                    $PRIVATE:PrivateVariablesHash += @{$Var.Name = $Var.Value}
                }
            }
            else{
                $PRIVATE:PrivateVariablesHash += @{$Var.Name = $Var.Value}
            }
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
    }
    $PrivateVariablesHash
}