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

function Install-DryDependencies{
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ConfigCombo,

        [Parameter(Mandatory,HelpMessage="To determine which depdencies_hash to write to")]
        [ValidateSet('environment','module','system')]
        [string]$Type,

        [string]$GitsPath
    )

    try{
        ol i " "
        ol i "Dependencies" -sh

        switch($Type){
            'environment'{
                $Dependencies = $ConfigCombo.envconfig.dependencies
            }
            'module'{
                $Dependencies = $ConfigCombo.moduleconfig.dependencies
            }
            'system'{
                $Dependencies = $ConfigCombo.systemconfig.dependencies
            }
        }

        # Chocolatey packages must be installed elevated
        #! should check if they are installed before throwing error
        if($Dependencies.choco.packages.count -gt 0){
            if(-Not (Test-DryElevated)){
                ol w " "
                ol w "When modules depend on chocolatey packages, you should run"
                ol w "-init or -moduleinit elevated (i.e. 'Run as Administrator')"
                ol w " "
                throw "When modules depend on chocolatey packages, you should run -init or -moduleinit elevated (i.e. 'Run as Administrator')"
            }
        }

        # Install nuget modules
        if($Dependencies.nuget){
            ol i 'Nugets' -sh
            foreach($Module in $Dependencies.nuget.modules){
                ol i @('Nuget',$Module.name)
                Install-DryModule -Module $Module
            }
        }

        # Install Chocolatey packages
        if($Dependencies.choco){
            if($Dependencies.choco.packages.count -gt 0){
                ol i 'Chocos' -sh
                Install-DryChocolatey
                foreach($Package in $Dependencies.choco.packages){
                    ol i @('Choco',$Package.name)
                    $InstallChocoParams = @{
                        Name = $Package.name
                    }
                    if($Module.minimumversion){
                        $InstallChocoParams += @{
                            MinimumVersion = $Module.minimumversion
                        }
                    }
                    if($Module.requiredversion){
                        $InstallChocoParams += @{
                            RequiredVersion = $Module.requiredversion
                        }
                    }
                    Install-DryChocoPackage @InstallChocoParams 
                }
            }
        }

        # Download git projects to a PSModule path
        if($Dependencies.git){
            ol i 'GITs' -sh
            if(-not $GitsPath){ 
                [string]$UserProfile = [Environment]::GetEnvironmentVariable("UserProfile")
                [string]$GitsPath = ([Environment]::GetEnvironmentVariable("PSModulePath") -split ';') | Where-Object{ 
                    $_ -match ($UserProfile -replace '\\','\\')
                }
            }
            # Ensure $GitsPath exists
            if(-not (Test-Path -Path $GitsPath)){
                New-Item -Path $GitsPath -Force -ItemType Directory -ErrorAction Stop | Out-Null
            }
            
            foreach($Project in $Dependencies.git.projects){
                ol i @('Git',$Project.url)
                $InstallDryGitModuleParams = @{
                    Source = $Project.url
                    Path = $GitsPath
                }
                
                if($Project.branch){
                    $InstallDryGitModuleParams += @{
                        Branch = $Project.branch
                    }
                }
                Install-DryGitModule @InstallDryGitModuleParams
            }
        }

        # no catch - assume all dependencies are ensured, so write the dependencies_hash to the ConfigObject
        switch($Type){
            'system'{
                $ConfigCombo.systemconfig.dependencies_hash = $ConfigCombo.CalcDepHash($Dependencies)
            }
            'module'{
                $ConfigCombo.moduleconfig.dependencies_hash = $ConfigCombo.CalcDepHash($Dependencies)
            }
            'environment'{
                $ConfigCombo.envconfig.dependencies_hash = $ConfigCombo.CalcDepHash($Dependencies)
            }
        }
        $ConfigCombo.Save()
        ol i "Dependencies installed" -sh 
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}