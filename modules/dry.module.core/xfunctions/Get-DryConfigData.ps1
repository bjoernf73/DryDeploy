<# 
 This module provides core functionality for DryDeploy.

 
#>

function Get-DryConfigData{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $Path,

        [Parameter(HelpMessage="Object to merge changes into")]
        [PSCustomObject]
        $Configuration

    )
    try{
        if(-not $Configuration){
            $Configuration = New-Object PSCustomObject
        }
        $FullPath = Join-Path -Path (Resolve-DryUtilsFullPath -Path $Path) -ChildPath '*'
        $Files    = @(Get-ChildItem -Path $FullPath -Include '*.jsonc','*.json','*.yml','*.yaml' -ErrorAction Stop)
        
        foreach($File in $Files){
            switch($File.extension){
               {$_ -in '.json','.jsonc'}{
                    $ConfObject = Get-DryFromJson -Path $File.FullName -ErrorAction Stop  
                }
               {$_ -in '.yml','.yaml'}{
                    $ConfObject = Get-DryFromYaml -Path $File.FullName -ErrorAction Stop 
                }
            }
            $Configuration = (Merge-DryUtilsPSObjects -FirstObject $Configuration -SecondObject $ConfObject)
        }
        return $Configuration
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}