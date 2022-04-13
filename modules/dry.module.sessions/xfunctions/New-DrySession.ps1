<# 
 This module provides query functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.sessions/main/LICENSE
 
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

function New-DrySession {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$Computername,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential[]]$Credential,

        [Parameter(Mandatory)]
        [ValidateSet('PSSession','CIMSession')]
        [String]$SessionType,

        [Parameter()]
        [PSObject]$SessionConfig,

        [Parameter(HelpMessage="Do not throw errors, just return")]
        [Switch]$IgnoreErrors,

        [Parameter(HelpMessage="How many times to try - defaults to 10 times")]
        [Int]$MaxRetries = 10
    )

    try {
        $Established = $False
        $CredCounter = 0
        <#
            .SYNOPSIS
            When multiple credentials are passed in the Credential parameter,
            this function will iterate over those Credentials. The first time
            the function is called, the first Credential in the set is returned. 
            The second time, the second credential in the set is returned, and 
            so on. When there are no more Credentials in the set, it starts anew, 
            returning the first in the set, and so on.
        #>
        function Get-CurrentCredential {
            [CmdletBinding()]
            param (
                [Parameter(Mandatory)]
                [Ref]$CredCounter
            )
            [System.Management.Automation.PSCredential[]]$Credential = (Get-Variable -Name Credential -Scope 1 -ValueOnly)
           
            if ($CredCounter.Value -ge $Credential.count) {
                $CredCounter.Value = 0
                return $Credential[0]
            }
            else {
                $ThisCredCount = $CredCounter.Value
                $CredCounter.Value = $CredCounter.Value + 1
                return $Credential[$ThisCredCount]
            }
        }
      
        # Mandatories
        $DrySessionParams = @{
            ComputerName   = $Computername
            Authentication = 'Negotiate'
        }
        ol d -hash $DrySessionParams

        # Optionals
        if ($SessionConfig) {
            if ($SessionConfig.usessl -eq $True) {
                
                switch ($SessionType) {
                    'PSSession' {
                        if ($PSVersionTable.Platform -eq 'Unix') {
                            ol w "Configuring Sessiontype","$SessionType to $ComputerName over HTTP (HTTPS not working from Linux)"
                            $SessionTypeOption = "http"
                            # $SessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck
                        }
                        else {
                            ol v "Configuring Sessiontype","$SessionType to $ComputerName over SSL/HTTPS"
                            $SessionTypeOption = "https"
                            $SessionOption = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
                            $DrySessionParams += @{ 'UseSSL'=$True }
                            $DrySessionParams += @{ 'SessionOption'=$SessionOption }
                        }
                    }
                    'CIMSession' {
                        $SessionOption = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -UseSsl
                        $DrySessionParams += @{ 'SessionOption'=$SessionOption }
                    }
                } 
            }
            else {
                $SessionTypeOption = "http"
                ol v "Configuring Sessiontype","$SessionType to $ComputerName over HTTP (clear text if not within Windows domain)"
            }
        }
        else {
            ol v "No SessionConfig"
        }

        $RetryCount = 0
        switch ($SessionType) {
            'PSSession' {
                do {
                    $RetryCount++ 
                    $DrySessionParams['Credential'] = (Get-CurrentCredential -CredCounter ([Ref]$CredCounter))
                    $UserName = ($DrySessionParams['Credential']).UserName
                    ol i "$SessionType to $Computername ($SessionTypeOption)","$RetryCount of $MaxRetries, user $UserName ($(Get-Date -Format HH:mm:ss))"

                    try {   
                        $Session = New-PSSession @DrySessionParams -ErrorAction 'Stop'
                        if ($Session.Availability -eq "Available") {
                            $Established = $True
                        } 
                        else { 
                            if ($RetryCount -ge $MaxRetries) {
                                ol v "Status","FAILED"
                            }
                            else {
                                ol w "Sleep and retry","$($_.ToString())"
                                Start-Sleep -Seconds 10
                            } 
                        }
                    }
                    catch {
                        if ($RetryCount -ge $MaxRetries) {
                            ol v "Status","FAILED"
                        }
                        else {
                            ol w "Sleep and retry","$($_.ToString())"
                            Start-Sleep -Seconds 10
                        }
                    }
                }
                while ((-not $Established) -and ($RetryCount -lt $MaxRetries))
            }
            'CIMSession' {
                do {
                    $RetryCount++
                    $DrySessionParams['Credential'] = (Get-CurrentCredential -CredCounter ([Ref]$CredCounter))
                    $UserName = ($DrySessionParams['Credential']).UserName
                    ol i "$SessionType to $Computername ($SessionTypeOption)","$RetryCount of $MaxRetries, user $UserName ($(Get-Date -Format HH:mm:ss))"
                    
                    try {
                        $Session = New-CIMSession @DrySessionParams -ErrorAction 'Stop'
                        $Established = $True
                    }
                    catch {
                        if ($RetryCount -ge $MaxRetries) {
                            ol v "Status","FAILED"
                        }
                        else {
                            ol w "Sleep and retry","$($_.ToString())"
                            Start-Sleep -Seconds 10
                        }
                    }
                }
                while ((-not $Established) -and ($RetryCount -lt $MaxRetries))
            }
        }

        if ($Established -eq $True) {
            ol i "$SessionType","ESTABLISHED"
            $Session
        }
        else {
            ol w "$SessionType","FAILED"
            if (-not $IgnoreErrors) {
                throw "Session of type $SessionType to $ComputerName could not be established"
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    } 
}