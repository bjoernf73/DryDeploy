<# 
 This module provides core functionality for DryDeploy.

 
#>

function New-DryItem{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [String[]]$Items,

        [Parameter(Mandatory)]
        [ValidateSet('Directory','File')]
        [string]$ItemType
    )

    try{
        foreach($Item in $Items){
            if(Test-Path -Path "$Item" -ErrorAction Ignore){
                $ExistingItem = Get-Item -Path "$Item" -ErrorAction Stop
                switch($ItemType){
                    'Directory'{
                        if($false -eq $ExistingItem.PSIsContainer){
                            throw "Item '$($ExistingItem.FullName)' is of wrong type"
                        }
                    }
                    'File'{
                        if($true -eq $ExistingItem.PSIsContainer){
                            throw "Item '$($ExistingItem.FullName)' is of wrong type"
                        }
                    }
                }
            }
            else{
                New-Item -ItemType $ItemType -Path "$Item" -Force | Out-Null
            }
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
        $ExistingItem = $null
    }
}