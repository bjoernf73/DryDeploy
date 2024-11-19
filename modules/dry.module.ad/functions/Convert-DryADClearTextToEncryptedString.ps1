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
function Convert-DryADClearTextToEncryptedString {
    [CmdletBinding()]
    [OutputType([System.String])]
    param ( 
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ClearText,
        
        [Parameter(Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string] $CertificateFile
    )

    try {
        # Encrypts 
        ol v @("CertificateFile", $CertificateFile)
        $PublicCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificateFile)
        # System.Security.Cryptography.ECDsa eCDsa = certificate.GetECDsaPublicKey(); // This line causes an exception - the certificate key pair must be RSA
        $ByteArray = [System.Text.Encoding]::UTF8.GetBytes($ClearText)
        $EncryptedByteArray = $PublicCert.PublicKey.Key.Encrypt($ByteArray, $true)
        $EncryptedBase64String = [Convert]::ToBase64String($EncryptedByteArray)
        return $EncryptedBase64String 
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
