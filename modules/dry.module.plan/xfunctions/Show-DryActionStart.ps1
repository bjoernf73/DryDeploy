<# 
    This module contains functions to resolve, get, modify and show a DryDeploy 
    Plan.  

    Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
   #>

function Show-DryActionStart{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [DryAction] $Action
    )
    try{
            ol i " "
            ol i "Resource:      [$($Action.ResourceName)]"
        if($Action.Phase){
            ol i "Action:        [$($Action.Action)] - Phase [$($Action.Phase)]"
        }
        else{ 
            ol i "Action:        [$($Action.Action)]"
        }
            ol i " "
            ol i "Description:   $($Action.Description)"
            ol i " "
            ol i " " -h
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}