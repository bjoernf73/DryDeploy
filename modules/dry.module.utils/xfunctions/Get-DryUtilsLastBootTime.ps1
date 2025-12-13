<# 
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>


function Get-DryUtilsLastBootTime{
    [cmdletbinding()]            
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    $ScriptBlock ={
        try{
            $Result = ( 
                Get-CimInstance -ClassName win32_operatingsystem | 
                Select-Object -Property lastbootuptime).lastbootuptime 
            return $Result
        }
        catch{
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    try{
        $BootTime = Invoke-Command -session $Session -ScriptBlock $scriptblock

        if($BootTime -is [DateTime]){
            return $BootTime
        }
        else{
            throw "$BootTime"
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}