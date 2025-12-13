<#
 This module handles credentials for DryDeploy

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.credential/main/LICENSE
#>

function New-DryCredentialsFile{
    [CmdLetBinding()]
    param(
        $Path
    )

    try{
        
        if(Test-Path -Path $Path -ErrorAction SilentlyContinue){
            ol d "The Credentials file exists already"
        }
        else{
            $Credentials = [PSCustomObject]@{
                credentials = @()
                path        = "$Path"
                accessed    = $null
            }
            Save-DryUtilsToJson -Path $Path -InputObject $Credentials 
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }    
}