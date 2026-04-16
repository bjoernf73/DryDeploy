<#
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function ConvertTo-DryUtilsDomainDN{
    [CmdLetBinding()]
    param(
        [ValidateScript({$_ -match "^[a-zA-Z0-9][a-zA-Z0-9-_]{0,61}[a-zA-Z0-9]{0,1}\.([a-zA-Z]{1,6}|[a-zA-Z0-9-]{1,30}\.[a-zA-Z]{2,3})$"})]
        [string]$DomainFQDN
    )
    try{
        $DomainDN = ""
        $FQDNParts = $DomainFQDN.Split(".")
        for ($i = 0; $i -le ($FQDNParts.Count - 1); $i++){
            $DomainDN += "DC=$(${FQDNParts}[$i]),"
        }
        $DomainDN = $DomainDN.Remove($DomainDN.Length - 1, 1)
        return $DomainDN
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
        Remove-Variable -name DomainFQDN,FQDNParts -ErrorAction Ignore
    }
}