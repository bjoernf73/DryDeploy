<# 
 This module provides functions for bootstrapping package management, 
 registering package sources and package installations for use with 
 DryDeploy. ModuleConfigs may specify dependencies in it's root config
 that this module processes.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.packagemanagement/main/LICENSE
#>

function Install-DryChocolatey{ 
    [CmdLetBinding()]
    param()

    try{
        $ChocoInstallUri = 'https://chocolatey.org/install.ps1'
        if(-not (Test-DryExeAvailability -Exe 'choco.exe')){
            if(Test-DryElevated){
                Set-ExecutionPolicy Bypass -Scope Process -Force
                Invoke-WebRequest -Uri "$ChocoInstallUri" -UseBasicParsing -ErrorAction Stop | 
                Invoke-Expression -ErrorAction Stop
            }
            else{
                throw "To install chocolatey, you must elevate (i.e. 'Run as Administrator')"
            }
        }
        else{
            ol v "Chocolatey is installed"
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}