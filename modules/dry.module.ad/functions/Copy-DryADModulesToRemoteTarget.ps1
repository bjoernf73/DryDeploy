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
function Copy-DryADModulesToRemoteTarget {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSSession]$PSSession,

        [Parameter(Mandatory)]
        [string]$RemoteRootPath,

        [Parameter(Mandatory)]
        [array]$Modules,

        [Parameter(Mandatory)]
        [array]$Folders,

        [Parameter(HelpMessage = 'Remove the remote root before copy')]
        [switch]$Force
    )

    try {
        # While copying multiple tiny files, the progress bar is flickering and not informative at all, so suppress it
        $OriginalProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
       
        if ($Force) {
            $InvokeDirParams = @{
                ScriptBlock  = $DryAD_SB_RemoveAndReCreateDir
                Session      = $PSSession
                ArgumentList = @($RemoteRootPath)
            }
            $DirResult = Invoke-Command @InvokeDirParams
            
            switch ($DirResult) {
                $True {
                    ol d 'Created remote directory', "$RemoteRootPath"
                }
                { $DirResult -is [ErrorRecord] } {
                    ol w 'Unable to create remote directory', "$RemoteRootPath"
                    $PSCmdlet.ThrowTerminatingError($DirResult)
                }
                default {
                    throw "Unable to create remote directory: $($DirResult.ToString())"
                }
            }
        }

        foreach ($Module in $Modules) {
            [PSModuleInfo]$ModuleObj = Get-Module -Name $Module -ListAvailable -ErrorAction Stop
            if ($null -eq $ModuleObj) {
                throw "Unable to find module '$Module'"
            }
            else {
                $ModuleFolder = Split-Path -Path $ModuleObj.Path
                $CopyItemsParams = @{
                    Path        = $ModuleFolder
                    Destination = $RemoteRootPath 
                    ToSession   = $PSSession 
                    Recurse     = $True
                    Force       = $True
                }
                ol d @("Copying module to '($PSSession.ComputerName)'", "'$ModuleFolder'")
                Copy-Item @CopyItemsParams
            }
        }

        foreach ($ModuleFolder in $Folders) {
            try {
                [system.io.directoryinfo]$ModuleObj = Get-Item -Name $ModuleFolder -ErrorAction Stop
                $CopyItemsParams = @{
                    Path        = $ModuleFolder
                    Destination = $RemoteRootPath 
                    ToSession   = $PSSession 
                    Recurse     = $True
                    Force       = $True
                }
                ol d @("Copying module to '($PSSession.ComputerName)'", "'$ModuleFolder'")
                Copy-Item @CopyItemsParams
            }
            catch {
                throw "Failed to copy '$ModuleFolder' to remote target"
            }
        }
        
        # Add RemoteRootPath to $env:PSModulePath on the remote system, so functions are
        # available without explicit import. Prepare $RemoteRootPath and a $RemoteRootPathRegex 
        # that allows us to test if the path is already added or not. 
        
        # Change double backslash to single, remove trailing backslash, and lastly make all 
        # single backslashes double in the regex
        $RemoteRootPath = ($RemoteRootPath.Replace('\\', '\')).TrimEnd('\')         
        $RemoteRootPathRegEx = $RemoteRootPath.Replace('\', '\\')

        $InvokePSModPathParams = @{
            ScriptBlock  = $DryAD_SB_PSModPath
            Session      = $PSSession 
            ArgumentList = @($RemoteRootPath, $RemoteRootPathRegEx)
        }
        $RemotePSModulePaths = Invoke-Command @InvokePSModPathParams

        ol d @('The PSModulePath on remote system', "'$RemotePSModulePaths'")
        switch ($RemotePSModulePaths) {
            { $RemotePSModulePaths -Match $RemoteRootPathRegEx } {
                ol v @('Successfully added to remote PSModulePath', "'$RemoteRootPath'")
            }
            default {
                ol w @('Failed to add path to remote PSModulePath', "'$RemoteRootPath'")
                throw "The RemoteRootPath '$RemoteRootPath' was not added to the PSModulePath in the remote session"
            }
        }

        if ($Force) {
            $ImportModsParams = @{
                Session      = $PSSession 
                ScriptBlock  = $DryAD_SB_ImportMods 
                ArgumentList = @($Modules)
                ErrorAction  = 'Stop' 
            }   
            $ImportResult = Invoke-Command @ImportModsParams
    
            switch ($ImportResult) {
                $True {
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
