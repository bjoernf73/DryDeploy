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
Function Get-DryADCredential {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [ValidateScript({ ("$_" -split '\\').count -eq 2 })]
        [String]$UserName,
        
        [Parameter()]
        [Int]$Length = 20,

        [Parameter()]
        [Int]$NonAlphabetics = 5,

        [Switch]$Random
    )
    try {
        If ($Random) {
            [SecureString]$SecStringPassword = Get-DryADRandomString -Length $Length -NonAlphabetics $NonAlphabetics -Secure
            [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($UserName, $SecStringPassword)
        }
        Else {
            [PSCredential]$Credential = Get-Credential -UserName $UserName -Message "Specify password for '$UserName'"
        }
        Return $Credential
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
        $SecStringPassword = $Null
    }
}
