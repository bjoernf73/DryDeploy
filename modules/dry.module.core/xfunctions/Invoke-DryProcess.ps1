<# 
 This module provides core functionality for DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.core/main/LICENSE
 
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

function Invoke-DryProcess {
    [CmdLetBinding()]
    param (
        [string]$Command, 
        [string]$Arguments
    )
    try {
        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $Command
        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true
        $pinfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $pinfo.Arguments = $Arguments

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $pinfo
        $p.Start() #| Out-Null

        $StdOutStr = ""
        $StdErrStr = ""

        While (-not ($p.StandardError.EndOfStream)) {
            $StdErrStr = $StdErrStr + $p.StandardError.ReadLine()
        }

        While (-not ($p.StandardOutput.EndOfStream)) {
            $StdOutStr = $StdOutStr + $p.StandardOutput.ReadLine()
        }

        $RetObj = [pscustomobject]@{
            Command = $Command
            Arguments = $Arguments
            StdOut = $StdOutStr
            StdErr = $StdErrStr
            ExitCode = $p.ExitCode  
        }
        $p.WaitForExit()
        return $RetObj
    }
    catch {
        $p.Dispose()
        throw $_
    }
}