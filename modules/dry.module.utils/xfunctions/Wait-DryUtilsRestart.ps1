<# 
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>


function Wait-DryUtilsRestart{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName,

        [Parameter()]
        [int]$MinimumTimeOuts = 3

    )

    throw "This function does not do anything until it is written"
     
    [bool]$RebootConfirmed = $false
    $TestResults = @()
    for ($i=0; $i -lt $MinimumTimeOuts; $i++){
        $TestResults += $false
    }

    do{
        if( Test-Connection -ComputerName $ComputerName -Protocol TCP -Count 1 ){
            # Add result to $TestResults
        }
    }
    while (-not $RebootConfirmed)
}