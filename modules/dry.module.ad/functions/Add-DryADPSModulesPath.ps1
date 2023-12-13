using NameSpace System.Management.Automation
using NameSpace System.Management.Automation.Runspaces
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
function Add-DryADPSModulesPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSSession]$PSSession,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(HelpMessage = 'Forcefully import the modules into the session')]
        [string[]]$Modules
    )

    try {
        
        
        # Add Path to $env:PSModulePath on the remote system, so functions are
        # available without explicit import. 
        
        # Change double backslash to single, remove trailing backslash, and lastly make all 
        # single backslashes double in the regex
        $Path = ($Path.Replace('\\', '\')).TrimEnd('\')         
        $PathRegEx = $Path.Replace('\', '\\')

        $InvokePSModPathParams = @{
            ScriptBlock  = $DryAD_SB_PSModPath
            Session      = $PSSession 
            ArgumentList = @($Path, $PathRegEx)
        }
        $RemotePSModulePaths = Invoke-Command @InvokePSModPathParams

        ol v @('The PSModulePath on remote system', "'$RemotePSModulePaths'")
        switch ($RemotePSModulePaths) {
            { $RemotePSModulePaths -Match $PathRegEx } {
                ol v @('Successfully added to remote PSModulePath', "'$Path'")
            }
            default {
                ol w @('Failed to add path to remote PSModulePath', "'$Path'")
                throw "The RemoteRootPath '$Path' was not added to the PSModulePath in the remote session"
            }
        }

        if ($Modules) {
            $ImportModsParams = @{
                Session      = $PSSession 
                ScriptBlock  = $DryAD_SB_ImportMods 
                ArgumentList = @($Modules)
                ErrorAction  = 'Stop' 
            }   
            $ImportResult = Invoke-Command @ImportModsParams
    
            switch ($ImportResult) {
                $true {
                    ol s "Modules were imported into the session"
                    ol v "The modules '$Modules' were imported into PSSession to $($PSSession.ComputerName)"
                }
                default {
                    ol f "Modules were not imported into the session"
                    ol w "The modules '$Modules' were not imported into PSSession to $($PSSession.ComputerName)"
                    throw "The modules '$Modules' were not imported into PSSession to $($PSSession.ComputerName)"
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $ProgressPreference = $OriginalProgressPreference
    }
}
