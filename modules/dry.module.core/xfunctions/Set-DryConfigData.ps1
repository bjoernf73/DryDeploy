<#
 This module provides core functionality for DryDeploy.


#>

function Set-DryConfigData{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateSet('json','yml')]
        [string]$Type,

        [Parameter(Mandatory)]
        [System.Text.Encoding]$Encoding,

        [Parameter(Mandatory,HelpMessage="Object to write to file")]
        [PSCustomObject]$Configuration
    )
    try{
        $FullPath = Resolve-DryUtilsFullPath -Path $Path
        $Folder = Split-Path -Path $FullPath -ErrorAction Stop -Parent -ErrorAction Stop
        if(-not(Test-Path -Path $FolderPath -ErrorAction Ignore)){
            New-Item -Path $Folder -ItemType Directory -Force -Confirm:$false -ErrorAction Stop
        }
        switch($Type){
            'json'{
                $Configuration = ConvertTo-Json -DryFromJson -Path $File.FullName -Force -Confirm:$false -ErrorAction Stop
            }
            'yml'{
                try{
                    $Configuration | ConvertTo-Yaml -Path $File.FullName -ErrorAction Stop
                }
                catch [System.Management.Automation.CommandNotFoundException]{
                    ol w 'Missing Powershell Module','powershell-yaml'
                    throw $_
                }
                catch{
                    throw $_
                }

            }
        }

    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}