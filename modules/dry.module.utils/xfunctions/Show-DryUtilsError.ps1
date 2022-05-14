<# 
 This module provides core functionality for DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.core/main/LICENSE
 
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

<#
function Show-DryUtilsError {
    [cmdletbinding()]
    param (
        [Management.Automation.ErrorRecord]$Err
    )
    
    $StackTraceLine = @($Err.ScriptStackTrace -Split "`n")[0]
    
    $ErrParts1 = $StackTraceLine.Split(',')
    $Function = ($ErrParts1[0]).TrimStart('at ')
    $ErrParts2 = $ErrParts1[1] -Split ': '
    $Script = ($ErrParts2[0]).Trim()
    # $ScriptLeaf = Split-Path -Path $Script -Leaf
    # $ScriptDir = Split-Path -Path $Script -Parent
    $Line = (($ErrParts2[1]).Trim()).TrimStart('line ')
    
    # Add Function, Script and Line
    $ErrObject = New-Object -TypeName PSObject -Property @{
        'Function'=$Function
        'Script'=$Script
        'Line'=$Line
    }
    # Add the exception
    $ErrObject | 
    Add-Member -MemberType NoteProperty -Name 'Exception' -Value "$($Err.Exception)"

    # Add category info properties
    ($Err.CategoryInfo).PSObject.Properties | foreach-Object {
        $ErrObject | 
        Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value
    } 
    # Show the error object
    Write-Host ($ErrObject | Format-List | Out-String) -Foregroundcolor 'Red'
}
#>

function Show-DryUtilsError {
    [cmdletbinding()]
    param (
        [Management.Automation.ErrorRecord]$Err
    )
    ol i " " 
    ol i "Terminating Error Info" -sh -Fore Red
    ol i " " 
    $StackTraceLine = @($Err.ScriptStackTrace -Split "`n")[0]
    $ErrParts1      = $StackTraceLine.Split(',')
    $Function       = ($ErrParts1[0]).TrimStart('at ')
    $ErrParts2      = $ErrParts1[1] -Split ': '
    $Script         = ($ErrParts2[0]).Trim()
    $Line           = (($ErrParts2[1]).Trim()).TrimStart('line ')

    ol i @('Function',$Function) -Fore Red
    ol i @('Script',$Script) -Fore Red
    ol i @('Line',$Line) -Fore Red
    
    $Exceptions = $Err.Exception.ToString() -split "`n"
    $Exc = 1
    $Exceptions.ForEach({
        ol i @("Exception $Exc","$($_.Trim())") -Fore Red
        $Exc++
    })

    $Err.CategoryInfo.PsObject.Properties.foreach({
        if ($null -ne $_.value) {
            ol i @("$($_.Name)","$($_.Value)") -Fore Red
        }
    })
    ol i " " -h -Fore Red
    ol i " "
}