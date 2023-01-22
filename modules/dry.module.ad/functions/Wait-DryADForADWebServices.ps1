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
        [String]
        $DomainDN,

        [Parameter(Mandatory)]
        [PSSession]
        $PSSession,

        [Parameter(HelpMessage = "How long should I try this without success?")]
        [Int]
        $WaitMinutes = 20
  
    )
    [Boolean]$ADWebServicesUp = $False
    [String]$DomainControllersOUDN = "OU=Domain Controllers,$DomainDN"
    [DateTime]$StartTime = Get-Date
    Do {
        $TestResult = Invoke-Command -Session $PSSession -ScriptBlock { 
            param ($DomainControllersOUDN); 
            try {
                # If this works, return true
                Get-ADObject -Identity $DomainControllersOUDN | Out-Null
                $True
            } 
            catch {
                $False
            }
        } -ArgumentList $DomainControllersOUDN
        
        switch ($TestResult) {
            $True {
                ol i "Active Directory Web Services is now up and reachable."
                $ADWebServicesUp = $True
            }
            $False {
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
        $False {
            ol e "AD Webservices wasn't ready after waiting the configured $WaitMinutes minutes"
            throw "AD Webservices wasn't ready after waiting the configured $WaitMinutes minutes"
        }
        default {
        }
    }
}
