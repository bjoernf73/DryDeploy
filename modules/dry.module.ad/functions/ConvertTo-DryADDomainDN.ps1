<#  
    This is an AD Config module for use with DryDeploy, or by itself.
    Copyright (C) 2021  Bjørn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.ad/main/LICENSE

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
    Converts Domain FQDN to distinguishedName
#> 
function ConvertTo-DryADDomainDN {
    [CmdLetBinding()]
    param (
        [ValidateScript({ $_ -match "^[a-zA-Z0-9][a-zA-Z0-9-_]{0,61}[a-zA-Z0-9]{0,1}\.([a-zA-Z]{1,6}|[a-zA-Z0-9-]{1,30}\.[a-zA-Z]{2,3})$" })]
        [string]$DomainFQDN
    )

    try {
        $FQDNParts = $DomainFQDN.Split(".")
        $DomainDN = ""
        for ($i = 0; $i -le ($FQDNParts.Count - 1); $i++) {
            $DomainDN += "DC=$(${FQDNParts}[$i]),"
        }
        $DomainDN = $DomainDN.Remove($DomainDN.Length - 1, 1)
        return $DomainDN
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        @('DomainFQDN', 'FQDNParts').foreach({
                Remove-Variable -Name $_ -ErrorAction Ignore
            })
    }
}
