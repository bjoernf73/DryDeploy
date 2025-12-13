<# 
    This module contains functions to resolve, get, modify and show a DryDeploy 
    Plan.  

    Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
   #>

function Set-DryPlan{

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $PlanFile,

        [Parameter(Mandatory)]
        [Plan]   $Plan
    )
    $Plan.Save($PlanFile,$false)
}