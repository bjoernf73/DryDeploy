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

Function Install-DryDSCmodule {
    
    [cmdletbinding()] 
    Param (
        [Parameter(Mandatory=$True,ValueFromPipeline=$true)]
        [PSObject[]]$ModuleObject,

        [Parameter(Mandatory=$False,ValueFromPipeline=$false)]
        [System.Management.Automation.Runspaces.PSSession]$Session
    )
    Begin {
        If ($Session) {
           $Remote = $True
            ol v "Installing modules on remote target '$($Session.Computername)'" 
        }
        Else {
            $Remote = $False
            ol v "Installing modules on local system" 
        }
    }
    Process {
        $Result = $null
        $ModuleName = "$($_.name)"
        # version
        If ($_.requiredversion) {
            $Version = $_.requiredversion
        } 
        ElseIf ($_.minimumversion) {
            $Version = $_.minimumversion
        } 
        ElseIf ($_.maximumversion) {
            $Version = $_.minimumversion
        }
        
        # info to log
       ol v "Checking module: '$ModuleName', version: '$Version'" 
        Try {
            If ($Session) {
                # remote and start
                $Result = Invoke-Command -session $Session -ScriptBlock {
                    [CmdletBinding()]
                    Param (
                            $ModuleName,
                            $Version
                    )
                    Try {
                        If (Get-Module -ListAvailable -Name $ModuleName | Where-Object { $_.version -eq $Version } ) {
                            Return "AlreadyInstalled"
                        } 
                        Else {
                            Install-PackageProvider nuget -Force | 
                            Out-Null
                            # here you should add versions, install-module supports max and min versions etc
                            $InstallModuleParams = @{
                                'Name'=$ModuleName
                                'RequiredVersion'=$Version
                                'ErrorAction'='Stop'
                                'Confirm'=$False
                                'Force'=$True
                            }
                            
                            Install-Module @InstallModuleParams
                            Return "Installed"
                        }
                    } 
                    Catch {
                        $_
                    }
                } -ArgumentList $ModuleName,$Version
            } 
            Else {
                Try {
                    If (get-module -ListAvailable -Name $ModuleName | Where-Object { $_.version -eq $Version } ) {
                        ol v 'DSC Module already installed',"$ModuleName ($Version)"  
                        $Result = "AlreadyInstalled"
                    } 
                    Else {
                       ol v "Module not installed: '$ModuleName', version: '$Version', trying to install." 
                        
                        #Install-PackageProvider -Name 'nuget' -Scope CurrentUser -force 4>>$GLOBAL:VerboseStreamFile 6>>$GLOBAL:InfoStreamFile 1>>$GLOBAL:SuccessStreamFile
                        #Output-Streams 
                        # here you should add versions, install-module supports max and min versions etc
                        Install-Module -Name $ModuleName -RequiredVersion $Version -Scope CurrentUser -Force -Confirm:$false 

                        $Result = "Installed"
                    }
                }
                Catch {
                    ol e "Some error occured during update/install of modules"
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        Finally {
            If ($Result -is [System.Management.Automation.ErrorRecord]) {
               ol v 'Unable to install DSC module',"$name"
               $PSCmdlet.ThrowTerminatingError($Result)
            } 
            ElseIf ($Result -eq "AlreadyInstalled") {
                ol i 'DSC Module already installed',"$ModuleName ($Version)" 
            } 
            ElseIf ($Result -eq "Installed") {
                ol i 'DSC Module installed',"$ModuleName ($Version)" 
            } 
            Else {
                throw "Unknown return type? ($Result)"
            }
        }
    } # Process 
    End {
        If ($Remote) {
           ol v "Done Installing modules on remote system '$($Session.Computername)'" 
        }
        Else {
           ol v "Done Installing modules on local system" 
        }
    }
}