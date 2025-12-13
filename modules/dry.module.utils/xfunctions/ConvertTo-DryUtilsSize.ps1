<# 
    This module provides utility functions for use with DryDeploy.

    Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function ConvertTo-DryUtilsSize{            
    [cmdletbinding()]            
    param(   
        [Parameter(Mandatory)]            
        [string]$Value,
           
        [validateset("Bytes","KB","MB","GB","TB")]            
        [string]$To,            
                    
        [int]$Precision = 4            
    )
    ol v "Got '$Value' to convert to '$To'." 

    $Value = $Value.Trim()
    switch($Value){            
       {$_ -match "^\d+$"}{ 
            [double]$NewValue = $_ 
        }            
       {$_ -match "^\d+KB$"}{
            [double]$Newvalue = $_.Remove(($_.Length-2),2)
            $Newvalue = $NewValue * 1024 }            
       {$_ -match "^\d+MB$"}{
            [double]$Newvalue = $_.Remove(($_.Length-2),2)
            $Newvalue = $NewValue * 1024 * 1024}            
       {$_ -match "^\d+GB$"}{
            [double]$Newvalue = $_.Remove(($_.Length-2),2)
            $Newvalue = $NewValue * 1024 * 1024 * 1024}            
       {$_ -match "^\d+TB$"}{
            [double]$Newvalue = $_.Remove(($_.Length-2),2)
            $Newvalue = $NewValue * 1024 * 1024 * 1024 * 1024} 
        default{
            throw "I don't regonize '$value' as a number to convert?"
        }            
    }            
    
    ol v "Value in bytes is '$NewValue'." 
    switch($To){            
        "Bytes"{return $NewValue}            
        "KB"{$NewValue = $NewValue/1KB}            
        "MB"{$NewValue = $NewValue/1MB}            
        "GB"{$NewValue = $NewValue/1GB}            
        "TB"{$NewValue = $NewValue/1TB}                         
    }            
    ol v "The new value in '$to' is '$NewValue'"           
    return [Math]::Round($Newvalue,$Precision,[MidPointRounding]::AwayFromZero)               
}