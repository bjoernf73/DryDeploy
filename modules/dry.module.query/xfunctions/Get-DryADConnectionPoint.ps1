<# 
 This module provides query functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.query/main/LICENSE
 
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
.SYNOPSIS
Gets a an Active Directory Connection Point, which is a computer that
allows DC, returning it's short name, DomainFQDN, or IP 

.DESCRIPTION
Queries the Configuration, and test's available DC's, preferring the
closest one. Test's which DC is responding, returning that. You may 
specify the format you want returned, whether it's the short name, 
full FQDN ir IP. 
   
.PARAMETER Configuration
The full $Configuration 

.EXAMPLE
Get-DryDC -Configuration $Configuration -Resource $Resource
Return's IP of the DC at the $Resource's site, if there is
one and it's pingable 

.EXAMPLE
\n
$Params = @{
'Configuration'=$Configuration; 
'Resource'=$Resource 
}
Get-DryDC @params -DomainFQDN -NoPing

Return's DomainFQDN of the DC at the $Resource's site, if there 
is one, even though it's down (unpingable)
#>
function Get-DryADConnectionPoint {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [PSObject]$Configuration,

        [Parameter(Mandatory)]
        [PSObject]$Resource,

        [Parameter(HelpMessage="Credential with right to winrm in to the connection point")]
        [PSCredential] $Credential,

        [Parameter(Mandatory)]
        [ValidateSet('Local','Remote')]
        [String] $ExecutionType,

        [Parameter(HelpMessage="Don't validate the connection - just give it to me")]
        [Switch]$NoValidate
    )
    
    try {
        if ($null -ne $Resource.network.site) {
            $Site = $Configuration.CoreConfig.network.sites | Where-Object {
                $_.name -eq "$($Resource.network.site)"
            }
            if ($null -eq $Site) {
                throw "Unable to find site object matching name $($Resource.network.site)"
            }
            elseif ($Site -is [array]) {
                throw "Multiple references to site $($Resource.network.site) in `$Configuration.CoreConfig.network"
            }

            $ADConnectionPoints = $Site.active_directory_connection_points

            if ($null -eq $ADConnectionPoints) {
                ol w "The site $($Site.name) does not contain any entries in it's active_directory_connection_points property.`
                Make sure one or multiple IP's is defined as connection point for each site"
                throw "The site $($Site.name) does not contain any entries in it's active_directory_connection_points property"
            }
            elseif ($ADConnectionPoints -isnot [array]) {
                ol w "The site $($Site.name) does not contain an array of entries in it's active_directory_connection_points property.`
                Make sure an array of one or multiple IP's is defined as connection point for each site"
                throw "The site $($Site.name) does not contain an array of entries in it's active_directory_connection_points property"
            }

            $SessionConfig = $Configuration.CoreConfig.connections | Where-Object { $_.type -eq 'winrm'}

            [Bool]$ConnectionPointVerified = $False
            $PRIVATE:count = 0
            do {
                try {
                    if ($NoValidate) {
                        $ConnectionPointVerified = $True
                        $ADConnectionPoint = $ADConnectionPoints[$PRIVATE:count]
                    }
                    else {
                        if ($ExecutionType -eq 'Remote') {
                            # test remoting
                            if (Test-DryWinrm -ComputerName $ADConnectionPoints[$PRIVATE:count] -Credential $Credential -SessionConfig $SessionConfig) {
                                $ConnectionPointVerified = $True
                                $ADConnectionPoint = $ADConnectionPoints[$PRIVATE:count]
                            }
                        }
                        else {
                            # don't test remoting
                            if (Test-Connection -ComputerName $ADConnectionPoints[$PRIVATE:count] -Count 2 -ErrorAction Ignore ) {
                                $ConnectionPointVerified = $True
                                $ADConnectionPoint = $ADConnectionPoints[$PRIVATE:count]
                            }
                        }
                    } 
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                finally {
                    $PRIVATE:count++
                }
            }
            while (
                ($ConnectionPointVerified -eq $False) -and 
                ($PRIVATE:count -lt $ADConnectionPoints.count)
            )
        }
        else {
            ol v "The Resource $($Resource.name) does specify a site-property - PDC Emulator will be returned"
            $ADConnectionPoint = $Configuration.CoreConfig.network.pdc_emulator
        }
        ol i "Resolved AD Connection Point","$ADConnectionPoint"
        return $ADConnectionPoint
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}