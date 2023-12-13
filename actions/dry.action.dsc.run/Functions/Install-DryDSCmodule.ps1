# This module is an action module for use with DryDeploy. It runs a DSC 
# Config on a target
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.dsc.run/main/LICENSE
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

function Install-DryDSCmodule {
    
    [cmdletbinding()] 
    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [PSObject[]]$ModuleObject,

        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    Begin {
        if ($Session) {
           $Remote = $true
            ol v "Installing modules on remote target '$($Session.Computername)'" 
        }
        else {
            $Remote = $false
            ol v "Installing modules on local system" 
        }
    }
    Process {
        $Result = $null
        $ModuleName = "$($_.name)"
        # version
        if ($_.requiredversion) {
            $Version = $_.requiredversion
        } 
        elseif ($_.minimumversion) {
            $Version = $_.minimumversion
        } 
        elseif ($_.maximumversion) {
            $Version = $_.minimumversion
        }
        
        # info to log
       ol v "Checking module: '$ModuleName', version: '$Version'" 
        try {
            if ($Session) {
                # remote and start
                $Result = Invoke-Command -session $Session -ScriptBlock {
                    [CmdletBinding()]
                    param (
                            $ModuleName,
                            $Version
                    )
                    try {
                        if (Get-Module -ListAvailable -Name $ModuleName | Where-Object { $_.version -eq $Version } ) {
                            return "AlreadyInstalled"
                        } 
                        else {
                            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                            Install-PackageProvider nuget -Force | 
                            Out-Null
                            # here you should add versions, install-module supports max and min versions etc
                            $InstallModuleParams = @{
                                'Name'=$ModuleName
                                'RequiredVersion'=$Version
                                'ErrorAction'='Stop'
                                'Confirm'=$false
                                'Force'=$true
                            }
                            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                            Install-Module @InstallModuleParams
                            return "Installed"
                        }
                    } 
                    catch {
                        $_
                    }
                } -ArgumentList $ModuleName,$Version
            } 
            else {
                try {
                    if (get-module -ListAvailable -Name $ModuleName | Where-Object { $_.version -eq $Version } ) {
                        ol v 'DSC Module already installed',"$ModuleName ($Version)"  
                        $Result = "AlreadyInstalled"
                    } 
                    else {
                       ol v "Module not installed: '$ModuleName', version: '$Version', trying to install." 
                        
                        #Install-PackageProvider -Name 'nuget' -Scope CurrentUser -force 4>>$GLOBAL:VerboseStreamFile 6>>$GLOBAL:InfoStreamFile 1>>$GLOBAL:SuccessStreamFile
                        #Output-Streams 
                        # here you should add versions, install-module supports max and min versions etc
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        Install-Module -Name $ModuleName -RequiredVersion $Version -Scope CurrentUser -Force -Confirm:$false 

                        $Result = "Installed"
                    }
                }
                catch {
                    ol e "Some error occured during update/install of modules"
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        finally {
            if ($Result -is [System.Management.Automation.ErrorRecord]) {
               ol v 'Unable to install DSC module',"$name"
               $PSCmdlet.ThrowTerminatingError($Result)
            } 
            elseif ($Result -eq "AlreadyInstalled") {
                ol i 'DSC Module already installed',"$ModuleName ($Version)" 
            } 
            elseif ($Result -eq "Installed") {
                ol i 'DSC Module installed',"$ModuleName ($Version)" 
            } 
            else {
                throw "Unknown return type? ($Result)"
            }
        }
    } # Process 
    End {
        if ($Remote) {
           ol v "Done Installing modules on remote system '$($Session.Computername)'" 
        }
        else {
           ol v "Done Installing modules on local system" 
        }
    }
}