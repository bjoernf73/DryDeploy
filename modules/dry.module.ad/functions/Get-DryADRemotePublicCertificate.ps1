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
function Get-DryADRemotePublicCertificate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, HelpMessage = "PSSession to a Domain Controller")]
        [PSSession]
        $PSSession,
        
        [Parameter(Mandatory)]
        [String]
        $CertificateFile
    )

    try {
        $InvokeCommandParams = @{
            ScriptBlock  = $DryAD_SB_RemoteWebCert_Export
            Session      = $PSSession
            ArgumentList = @('C:\PublicCertificate.cer', @('SHA256RSA'), 'Server Authentication')
        }
        $Result = Invoke-Command @InvokeCommandParams
        
        if ($Result[0] -eq $true) {
            Copy-Item -FromSession $PSSession -Path 'C:\PublicCertificate.cer' -Destination "$CertificateFile" -Force -ErrorAction Stop
            ol i @('Fetched public certificate', "$CertificateFile")
        }
        else {
            throw "Failed getting remote public certificate: $($Result[1].ToString())"
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $InvokeRemoveParams = @{
            ScriptBlock  = $DryAD_SB_RemoveItem
            Session      = $PSSession
            ErrorAction  = 'Ignore'
            ArgumentList = @('C:\PublicCertificate.cer', 'Ignore')
        }
        Invoke-Command @InvokeRemoveParams | Out-Null
    }
}
