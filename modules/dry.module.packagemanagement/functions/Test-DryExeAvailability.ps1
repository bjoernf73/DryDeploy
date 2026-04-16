<#
 This module provides functions for bootstrapping package management,
 registering package sources and package installations for use with
 DryDeploy. ModuleConfigs may specify dependencies in it's root config
 that this module processes.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.packagemanagement/main/LICENSE
#>

function Test-DryExeAvailability{
    [CmdletBinding()]
    [OutputType([Bool])]
    param(
        [string]$exe
    )

    try{
        if(Get-Command -Name "$exe"){
            $true
        }
        else{
            $false
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}