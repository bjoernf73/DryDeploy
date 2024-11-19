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
function Wait-DryADForADWebServices {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $DomainDN,

        [Parameter(Mandatory)]
        [PSSession]
        $PSSession,

        [Parameter(HelpMessage = "How long should I try this without success?")]
        [int]
        $WaitMinutes = 20
  
    )
    [Boolean]$ADWebServicesUp = $false
    [string]$DomainControllersOUDN = "OU=Domain Controllers,$DomainDN"
    [DateTime]$StartTime = Get-Date
    Do {
        $TestResult = Invoke-Command -Session $PSSession -ScriptBlock { 
            param ($DomainControllersOUDN); 
            try {
                # If this works, return true
                Get-ADObject -Identity $DomainControllersOUDN | Out-Null
                $true
            } 
            catch {
                $false
            }
        } -ArgumentList $DomainControllersOUDN
        
        switch ($TestResult) {
            $true {
                ol i "Active Directory Web Services is now up and reachable."
                $ADWebServicesUp = $true
            }
            $false {
                #! should Out-DryLog have a wait-option?
                ol i "Waiting for Active Directory Web Services to become available...."
                Start-Sleep -Seconds 30
            }
            default {
                ol e "Error testing Active Directory Web Services"
                throw $TestResult
            }
        } 
    }
    While (
        (-not $ADWebServicesUp) -and
        (Get-Date -lt ($StartTime.AddMinutes($WaitMinutes)))
    )

    switch ($ADWebServicesUp) {
        $false {
            ol e "AD Webservices wasn't ready after waiting the configured $WaitMinutes minutes"
            throw "AD Webservices wasn't ready after waiting the configured $WaitMinutes minutes"
        }
        default {
        }
    }
}
