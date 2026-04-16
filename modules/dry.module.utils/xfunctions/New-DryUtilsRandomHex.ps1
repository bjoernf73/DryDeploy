<#
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function New-DryUtilsRandomHex{
    [CmdLetBinding()]
    [OutputType([System.String])]

    param(
        [Parameter(HelpMessage="Length of the random hex")]
        [int]$Length = 25
    )
    try{
        $Chars = '0123456789ABCDEF'
        [string]$Random = $null
        for ($i=1; $i -le $Length; $i++)    {
            $Random += $Chars.Substring((Get-Random -Minimum 0 -Maximum 15),1)
        }
        return $Random
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
        $i = $null
        $Random = $null
    }
}