Using NameSpace System.Management.Automation.Runspaces
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

[ScriptBlock]$DryAD_SB_RemoteWebCert_Export = {
    param (
        [String] $Path,
        [Array]  $SignatureAlgorithms,
        [String] $KeyUsage
    )
    try {
        $Cert = Get-ChildItem -Path Cert:\LocalMachine\My -ErrorAction Stop | Where-Object { 
            ($_.HasPrivateKey -eq $True) -and 
            ($_.SignatureAlgorithm.FriendlyName -in $SignatureAlgorithms) -and
            (@(($_.EnhancedKeyUsageList).FriendlyName) -contains $KeyUsage)  
        }

        # If multiple, use first
        if ($Cert -is [Array]) {
            $Cert = $Cert[0]
        }
        
        if ($Cert -is [System.Security.Cryptography.X509Certificates.X509Certificate2]) {
            Export-Certificate -Cert $Cert -FilePath $Path -Type CERT -Force -ErrorAction Stop | 
                Out-Null
        }
        else {
            throw "Certificate not found"
        }
        return @($True, '')
    }
    catch {
        return @($False, "$($_.ToString())")
    }
}
