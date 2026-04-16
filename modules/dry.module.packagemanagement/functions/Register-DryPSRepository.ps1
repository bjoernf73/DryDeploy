<#
 This module provides functions for bootstrapping package management,
 registering package sources and package installations for use with
 DryDeploy. ModuleConfigs may specify dependencies in it's root config
 that this module processes.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.packagemanagement/main/LICENSE
#>

function Register-DryPSRepository{
    [CmdLetBinding()]
    param(
        [PSObject]$Repository
    )

    try{
        try{
            $RegisteredRepository = Get-PSrepository -name $Repository.Name
            if($RegisteredRepository.InstallationPolicy -ne $Repository.InstallationPolicy){
                Set-PSRepository -Name $Repository.Name -InstallationPolicy $Repository.InstallationPolicy -ErrorAction Stop
            }
        }
        catch{
            if($_.CategoryInfo.Category -eq 'ObjectNotFound'){
                $RepositoryPropertiesHash = @{}
                $Repository.PSObject.Properties | foreach-Object{
                    $RepositoryPropertiesHash.Add($_.Name,$Repository.($_.Name))
                }
                $RepositoryPropertiesHash.Add('ErrorAction','Stop')
                Register-PSRepository @RepositoryPropertiesHash
            }
            else{
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}