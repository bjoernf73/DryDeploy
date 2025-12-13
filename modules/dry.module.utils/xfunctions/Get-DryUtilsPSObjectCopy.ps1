<# 
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function Get-DryUtilsPSObjectCopy{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,HelpMessage="The Object to make an unreferenced copy from")]
        [PSObject]$Object,

        [Parameter(HelpMessage="Properties to add or change")]
        [hashtable]$Properties
    )
  
    [PSObject]$Copy = $Object | ConvertTo-Json -Depth 100 -Compress -ErrorAction Stop | 
    ConvertFrom-Json -ErrorAction Stop
    
    # Will only work on properties at root though
    if($Properties){
        foreach($Key in $Properties.Keys){
            if($null -eq $Object."$Key"){
                Write-Host "The Property '$Key' does not exist!"
                $Object | Add-Member -MemberType NoteProperty -Name $Key -Value $Properties["$Key"]
            }
            else{
                Write-Warning "The Property '$Key' existed on the object already" -WarningAction Continue
                $Object."$Key" = $Properties["$Key"]
            }
        }
    }
    return $Copy
}