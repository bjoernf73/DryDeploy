<#
 This module handles credentials for DryDeploy

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.credential/main/LICENSE
 
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

function New-DryCredentialsFile {
    [CmdLetBinding()]
    param (
    )

    try {
        if ($null -eq $GLOBAL:CredentialsFile) {
            throw "The Global variable 'CredentialsFile' is unassigned"
        }

        if (Test-Path -Path $GLOBAL:CredentialsFile) {
            ol v "The Credentials file exists already"
        }
        else {
            "{""Credentials"": [],""Path"": """",""Accessed"": """"}" | 
            ConvertFrom-Json -ErrorAction Stop | 
            ConvertTo-Json -ErrorAction Stop | 
            Out-File -FilePath $GLOBAL:CredentialsFile -Encoding default -ErrorAction Stop
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }    
}