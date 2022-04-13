<# 
 This module provides functions for bootstrapping package management, 
 registering package sources and package installations for use with 
 DryDeploy. ModuleConfigs may specify dependencies in it's root config
 that this module processes.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.packagemanagement/main/LICENSE
 
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

function Install-DryGitModule { 
    [CmdLetBinding()]
    
    param (
        [Parameter(HelpMessage="The Source URI of the git repository to clone (or checkout)")]
        $Source,

        [Parameter(Mandatory,HelpMessage="Path to the directory the repository will be cloned (or checked out) into")]
        [ValidateScript({(Get-Item -Path $_) -is [System.IO.DirectoryInfo]})]
        [String]$Path,

        [Parameter(HelpMessage="The branch (or tag) to checkout")]
        [String]$Branch
    )

    try {
        Switch -Regex ($Source) {
            "[^/\\]{1,}(?=\.git$)" { 
                [String]$ProjectName = $Matches[0].ToString()
            }
            default {
                throw "Unable to understand the format of the source git repository source '$Source'"
            }
        }
        [String]$ProjectPath       = Join-Path -Path $Path -ChildPath $ProjectName
        [String]$ProjectDotGitPath = Join-Path -Path $ProjectPath -ChildPath '.git'

        if ((Test-Path -Path $ProjectPath) -and 
            (-not (Test-Path -Path $ProjectDotGitPath))) {
            throw "The target folder '$ProjectPath' exists, but is not a git project"
        }
        elseif (Test-Path -Path $ProjectPath) {
            Sync-GitBranch -RepoRoot $ProjectPath -ErrorAction Stop | Out-Null
        } 
        else {
            Copy-GitRepository -Source $Source -DestinationPath $ProjectPath -ErrorAction Stop
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    
    try {
        if ($Branch) {
            [Git.Automation.BranchInfo]$CurrentBranch = Get-GitBranch -RepoRoot $ProjectPath -Current -ErrorAction Stop
            if ($Branch -eq $CurrentBranch.Name) {
                Sync-GitBranch -RepoRoot $ProjectPath -ErrorAction Stop | Out-Null
            }
            else {
                Update-GitRepository -RepoRoot $ProjectPath -Revision $Branch -ErrorAction Stop | Out-Null
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}