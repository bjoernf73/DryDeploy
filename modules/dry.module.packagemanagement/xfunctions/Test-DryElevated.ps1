<# 
 This module provides functions for bootstrapping package management, 
 registering package sources and package installations for use with 
 DryDeploy. ModuleConfigs may specify dependencies in it's root config
 that this module processes.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.packagemanagement/main/LICENSE
#>

function Test-DryElevated{ 
    [CmdLetBinding()]
    [OutputType([Boolean])]
    param()

    try{
        if($PSVersionTable.Platform -eq 'Unix'){
            if((id -u) -eq 0){
                $true
            }
            else{
                $false
            }
        }
        else{
            if(([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')){
                $true
            }
            else{
                $false
            }
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}