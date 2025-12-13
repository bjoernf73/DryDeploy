<# 
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>

function Invoke-DryUtilsProcess{
    [CmdletBinding()]            
    param(
        [string]$Exe, 
        $Arguments
    )
    
    try{
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
    
        while(!($p.StandardOutput.EndOfStream)){
            $StdOutStr = $StdOutStr + "`n" + $p.StandardOutput.ReadLine() 
        }

        while(!($p.StandardError.EndOfStream)){
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
    catch{
        $p.Dispose()
        throw $_
    }
}