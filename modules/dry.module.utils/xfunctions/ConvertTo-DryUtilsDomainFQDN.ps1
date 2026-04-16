<#
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>


<#
	.Synopsis
	Converts a domain distinguishedName to domain FQDN
#>
function ConvertTo-DryUtilsDomainFQDN{
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({
            [RegEx]$rx = "^(dc|DC|Dc|dC)=.*,(dc|DC|Dc|dC)=.*";
            $Parts = $_ -Split ',';
            (($rx.Match($_)).Success -eq $true) -and ($Parts.foreach({
                    $_ -match "^(dc|DC|Dc|dC)=.*"
                })
            )
        })]
        [string]$DomainDN
    )

    try{
        $DomainDN2 = $DomainDN.Remove(0,3)
        $DNParts = $domainDN2 -Split "dc="
        $DomainFQDN = ""
        for ($i = 0; $i -le ($DNParts.Count - 1); $i++){
            $DNPart = ($DNParts[$i]).Trim(',') + '.'
            $DomainFQDN += $DNPart
        }
        $DomainFQDN = $DomainFQDN.Remove($DomainFQDN.Length - 1, 1)
        return $DomainFQDN
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
        @('DomainDN','DomainDN2','DNParts').foreach({
            Remove-Variable -Name $_ -ErrorAction Ignore
        })
    }
}