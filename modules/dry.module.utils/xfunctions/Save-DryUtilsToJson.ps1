<#
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function Save-DryUtilsToJson{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [PSObject]$InputObject,

        [Parameter()]
        [int]$Depth = 50,

        [Parameter()]
        [ValidateSet('ASCII','BigEndianUnicode','Default','OEM','String','Unicode','Unknown','UTF7','UTF8','UTF32')]
        [string]$Encoding = 'Default',

        [Parameter()]
        [Switch]$Force
    )

    try{
        $InputObject |
        ConvertTo-Json -Depth $Depth -ErrorAction Stop |
        Out-File -FilePath $Path -Encoding $Encoding -ErrorAction Stop -Force:$Force
    }
    catch{
        ol w @('Unable to save to',"$Path")
        $PSCmdlet.ThrowTerminatingError($_)
    }
}