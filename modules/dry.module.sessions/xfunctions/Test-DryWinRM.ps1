<# 
 This module establishes sessions to target machines for use by DryDeploy.

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

function Test-DryWinRM {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,HelpMessage="IP, FQDN or NetBIOS Host Name")]
        [string]$Computername,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Credential,

        [Parameter()]
        [PSObject]$SessionConfig
    )
    [Bool]$AvailableSession = $false
    try {
        $NewDrySessionParams = @{
            ComputerName  = $ComputerName
            Credential    = $Credential
            SessionConfig = $SessionConfig
            SessionType   = 'PSSession'
            IgnoreErrors  = $true
            MaxRetries    = 3
        }
        $Session = New-DrySession @NewDrySessionParams
        if ($Session.Availability -eq "Available") {
            $AvailableSession = $true
            $Session | Remove-PSSession -ErrorAction Ignore 
        }
        $AvailableSession
    }
    catch {
        $AvailableSession
    }
}