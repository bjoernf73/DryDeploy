<#
 This module provides functions for bootstrapping package management,
 registering package sources and package installations for use with
 DryDeploy. ModuleConfigs may specify dependencies in it's root config
 that this module processes.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.packagemanagement/main/LICENSE
#>

function Install-DryChocoPackage{
    [CmdLetBinding()]

    param(
        [Parameter(HelpMessage="Name of the Package to install")]
        [string]$Name,
        [string]$MinimumVersion,
        [string]$RequiredVersion
    )

    try{
        $InstallParams = @{
            Name = "$Name"
        }
        if($MinimumVersion){
            $InstallParams = @{
                Version = "$MinimumVersion"
            }
        }
        if($RequiredVersion){
            $InstallParams = @{
                Version = "$RequiredVersion"
            }
        }

        $Installed = Get-ChocoPackage -Name $Name -LocalOnly
        if($null -eq $Installed){
            Install-ChocoPackage @InstallParams
        }
        else{
            if($MinimumVersion){
                if($MinimumVersion -gt $Installed.Version){
                    # & "$($env:Programdata)\Chocolatey\bin\choco.exe" upgrade "$($_.Name)" -y
                    Install-ChocoPackage @InstallParams
                }
            }
            elseif($RequiredVersion){
                if($RequiredVersion -ne $Installed.Version){
                    $InstallParams +={
                        Force = $true
                    }
                    Install-ChocoPackage @InstallParams
                }
            }
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
        $Installed = $null
        $InstallParams = $null
    }
}