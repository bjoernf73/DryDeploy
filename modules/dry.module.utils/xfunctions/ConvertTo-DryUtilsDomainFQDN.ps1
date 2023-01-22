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


<# 
	.Synopsis 
	Converts a domain distinguishedName to domain FQDN 
#> 
function ConvertTo-DryUtilsDomainFQDN {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({
            [RegEx]$rx = "^(dc|DC|Dc|dC)=.*,(dc|DC|Dc|dC)=.*"; 
            $Parts = $_ -Split ',';
            (($rx.Match($_)).Success -eq $true) -and ($Parts.foreach({
                    $_ -match "^(dc|DC|Dc|dC)=.*"
                })
            )
        })]
        [String]$DomainDN
    )
    
    try {
        $DomainDN2 = $DomainDN.Remove(0,3)
        $DNParts = $domainDN2 -Split "dc="
        $DomainFQDN = ""
        for ($i = 0; $i -le ($DNParts.Count - 1); $i++) {
            $DNPart = ($DNParts[$i]).Trim(',') + '.'
            $DomainFQDN += $DNPart
        }
        $DomainFQDN = $DomainFQDN.Remove($DomainFQDN.Length - 1, 1)
        return $DomainFQDN
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        @('DomainDN','DomainDN2','DNParts').foreach({
            Remove-Variable -Name $_ -ErrorAction Ignore
        })
    }
}