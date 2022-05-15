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

function Invoke-DryUtilsProcess {
    [CmdletBinding()]            
    param (
        $Exe, 
        $Arguments
    )
    
    Try 
    {
        $process = New-Object System.Diagnostics.ProcessStartInfo
        $process.FileName = $exe
        $process.RedirectStandardError = $true
        $process.RedirectStandardOutput = $true
        $process.UseShellExecute = $false
        $process.CreateNoWindow = $true
        $process.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $process.Arguments = $Arguments

        $p = New-Object System.Diagnostics.Process
        $p.StartInfo = $process
        $p.Start() 

        $StdOutStr = ""
        $StdErrStr = ""
    
        while(!($p.StandardOutput.EndOfStream)) {
            $StdOutStr = $StdOutStr + "`n" + $p.StandardOutput.ReadLine() 
        }

        while(!($p.StandardError.EndOfStream)) {
            $StdErrStr = $StdErrStr  + "`n" + $p.StandardError.ReadLine()
        }

        $p.WaitForExit()

        $RetObj = [pscustomobject]@{
            Command = $exe
            Arguments = $Arguments
            StdOut = $StdOutStr
            StdErr = $StdErrStr
            ExitCode = $p.ExitCode  
        }
        
        return $RetObj
    }
    catch {
        $p.Dispose()
        throw $_
    }
}