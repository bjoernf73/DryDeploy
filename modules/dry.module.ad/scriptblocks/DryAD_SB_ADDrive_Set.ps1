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

[ScriptBlock]$DryAD_SB_ADDrive_Set = {
    param ($Server)
    try {
        $ReturnError = $Null
        $ReturnValue = $False
        $VerboseReturnStrings = @("Entered Scriptblock")

        # Make sure ActiveDirectory module is loaded, so the AD drive is mounted
        if ((Get-Module | Select-Object -Property Name).Name -notcontains 'ActiveDirectory') {
            try {
                Import-Module -Name 'ActiveDirectory' -ErrorAction Stop
                $VerboseReturnStrings += @("The AD PSModule was not loaded, but I loaded it successfully")
                Start-Sleep -Seconds 4
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        else {
            $VerboseReturnStrings += @("The AD PSModule was already loaded in session")
        }

        # However, that is not necessarily the case. That ActiveDirectory module is a bit sloppy 
        try {
            Get-PSDrive -Name 'AD' -ErrorAction Stop | 
                Out-Null
            $VerboseReturnStrings += @("The AD Drive exists already")
        }
        Catch [System.Management.Automation.DriveNotFoundException] {
            $VerboseReturnStrings += @("The AD Drive does not exist - trying to create it")
            
            try {
                $NewPSDriveParams = @{
                    Name        = 'AD' 
                    PSProvider  = 'ActiveDirectory' 
                    Root        = '//RootDSE/' 
                    ErrorAction = 'Stop'
                }
                New-PSDrive @NewPSDriveParams | Out-Null
            }
            catch {
                $VerboseReturnStrings += @("Failed to create the AD Drive: $($_.ToString())")
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        catch {
            $VerboseReturnStrings += @("The AD Drive did not exist, and an error occurred trying to get it?")
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Make sure the AD-drive is connected to $Server. This ensures that cmdlets operate on a specific Domain 
        # Controller, so that configs that depend on other configs exist on that Domain Controller, without needing
        # a full AD replication to have happened 
        $ADDrive = Get-PSDrive -Name 'AD' -ErrorAction Stop
        $ADDrive.Server = "$Server"

        # If we reached this, assume success
        $ReturnValue = $True
    }
    catch {
        $VerboseReturnStrings += "Set-DryADDrive failed"
        $ReturnError = $_
    }
    finally {
        @($VerboseReturnStrings, $ReturnValue, $ReturnError)
    }
}
