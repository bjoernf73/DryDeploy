<# 
 This module provides utility functions for use with DryDeploy.

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

function Test-DryUtilsPort {
    [Cmdletbinding()]
    param (  
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$ComputerName,

        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [Int]$Port,

        [Int]$Count = 1,

        [Int]$Delay = 500,
        
        [Int]$TcpTimeout = 1000,

        [Int]$UdpTimeout = 1000,

        [Switch]$Tcp,

        [Switch]$Udp
    )

    Begin {  
        if ((-not $Tcp) -and 
            (-not $Udp)) {
            $Tcp = $True
        }
        #Typically you never do this, but in this case I felt it was for the benefit of the Function  
        #as any errors will be noted in the output of the Report          
        $ErrorActionPreference   = 'SilentlyContinue'
        $Report                  = @()
        $StopWatch               = New-Object System.Diagnostics.Stopwatch
    }

    Process {
        foreach ($Computer in $ComputerName) {
            for ($i = 0; $i -lt $Count; $i++) {
                $Result          = New-Object PSObject | Select-Object Server, Port, TypePort, Open, Notes, ResponseTime
                $Result.Server   = $Computer
                $Result.Port     = $Port
                $Result.TypePort = 'TCP'

                if ($Tcp) {
                    $TcpClient   = New-Object System.Net.Sockets.TcpClient
                    $StopWatch.Start()
                    $Connect     = $TcpClient.BeginConnect($Computer, $Port, $null, $null)
                    $Wait        = $Connect.AsyncWaitHandle.WaitOne($TcpTimeout, $False)
                    
                    if (-not $Wait) {
                        $TcpClient.Close()
                        $StopWatch.Stop()
                        ol v "$($Computer): Connection Timeout"

                        $Result.Open  = $False
                        $Result.Notes = 'Connection to Port Timed Out'
                        $Result.ResponseTime = $StopWatch.ElapsedMilliseconds
                    }
                    else {
                        [void]$TcpClient.EndConnect($Connect)
                        $TcpClient.Close()
                        $StopWatch.Stop()

                        $Result.Open = $True
                    }
                    $Result.ResponseTime = $StopWatch.ElapsedMilliseconds
                }
                if ($Udp) {
                    $UdpClient = New-Object System.Net.Sockets.UdpClient
                    $UdpClient.Client.ReceiveTimeout = $UdpTimeout

                    $a = New-Object System.Text.ASCIIEncoding
                    $byte = $a.GetBytes("$(Get-Date)")

                    $Result.Server   = $Computer
                    $Result.Port     = $Port
                    $Result.TypePort = 'UDP'

                    ol v "$($Computer): Making UDP connection to remote server"
                    $StopWatch.Start()
                    $UdpClient.Connect($Computer, $Port)
                    ol v "$($Computer): Sending message to remote host"
                    [void]$UdpClient.Send($byte, $byte.Length)
                    ol v "$($Computer): Creating remote endpoint"
                    $RemoteEndpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)

                    try {
                        ol v "$($Computer): Waiting for message return"
                        $ReceiveBytes = $UdpClient.Receive([ref]$RemoteEndpoint)
                        $StopWatch.Stop()
                        [String]$ReturnedData = $a.GetString($ReceiveBytes)
                        
                        ol v "$($Computer): Connection Successful"
                            
                        $Result.Open  = $True
                        $Result.Notes = $ReturnedData
                    }
                    catch {
                        ol v "$($Computer): Host maybe unavailable"
                        $Result.Open  = $False
                        $Result.Notes = 'Unable to verify if port is open or if host is unavailable.'
                    }
                    finally {
                        $UdpClient.Close()
                        $Result.ResponseTime = $StopWatch.ElapsedMilliseconds
                    }
                }
                $StopWatch.Reset()
                $Report += $Result
                Start-Sleep -Milliseconds $Delay
            }
        }
    }
    End {
        $Report 
    }
}