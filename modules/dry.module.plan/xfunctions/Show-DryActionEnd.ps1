<# 
    This module contains functions to resolve, get, modify and show a DryDeploy 
    Plan.  

    Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
   #>

function Show-DryActionEnd{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [DryAction] $Action,

        [Parameter(Mandatory)]
        [DateTime] $StartTime,

        [Parameter(Mandatory)]
        [DateTime] $EndTime

    )
    try{
        switch($Action.Status){
            'SUCCESS'{ $OutPutColor = 'Green' }
            'FAILED' { $OutPutColor = 'Red' }
            Default  { $OutPutColor = 'Yellow' }
        }

        [timespan]$ActionSpan = ($EndTime-$StartTime)
            ol i " " -h
            ol i " "
        if($Action.Phase){
            ol i "Action [$($Action.action)] - Phase [$($Action.Phase)] took $($ActionSpan.ToString("dd\:hh\:mm\:ss")) to complete" -ForegroundColor $OutPutColor
        }
        else{
            ol i "Action [$($Action.action)] took $($ActionSpan.ToString("dd\:hh\:mm\:ss")) to complete" -ForegroundColor $OutPutColor
        }
        
            ol i " "
            ol i "Status: $($Action.Status.ToUpper())" -ForegroundColor $OutPutColor
            ol i " "
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}