<# 
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function Show-DryUtilsError{
    [cmdletbinding()]
    param(
        [Management.Automation.ErrorRecord]$Err
    )
    $StackTraceLine = @($Err.ScriptStackTrace -Split "`n")[0]
    $ErrParts1      = $StackTraceLine.Split(',')
    $function       = ($ErrParts1[0]).TrimStart('at ')
    $ErrParts2      = $ErrParts1[1] -Split ': '
    $Script         = ($ErrParts2[0]).Trim()
    $Line           = (($ErrParts2[1]).Trim()).TrimStart('line ')

    ol i @('Function',$Function) -Fore Red
    ol i @('Script',$Script) -Fore Red
    ol i @('Line',$Line) -Fore Red
    
    $Exceptions = $Err.Exception.ToString() -split "`n"
    $Exc = 1
    $Exceptions.foreach({
        ol i @("Exception $Exc","$($_.Trim())") -Fore Red
        $Exc++
    })

    $Err.CategoryInfo.PsObject.Properties.foreach({
        if($null -ne $_.value){
            ol i @("$($_.Name)","$($_.Value)") -Fore Red
        }
    })
    Write-Host " "
}