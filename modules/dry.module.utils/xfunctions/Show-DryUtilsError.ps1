<# 
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
 
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License along
 with this program; if not, write to the Free Software Foundation, Inc.,
 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
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