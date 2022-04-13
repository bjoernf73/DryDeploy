# This module is an action module for use with DryDeploy. It moves a computer 
# object in AD using the dry.module.ad module
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.ad.move/main/LICENSE
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

Function dry.action.ad.move {
    [CmdletBinding()]  
    Param (
        [Parameter(Mandatory,HelpMessage="The resolved action object")]
        [PSObject]$Action,

        [Parameter(Mandatory,HelpMessage="The resolved resource object")]
        [PSObject]$Resource,

        [Parameter(Mandatory,HelpMessage="The resolved global configuration object")]
        [PSObject]$Configuration,

        [Parameter(Mandatory,HelpMessage="ResourceVariables contains resolved variable values from the configurations common_variables and resource_variables combined")]
        [System.Collections.Generic.List[PSObject]]$ResourceVariables,

        [Parameter(Mandatory=$False,HelpMessage="Hash directly from the command line to be added as parameters to the function that iniates the action")]
        [HashTable]$ActionParams
    )

    Try {
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   OPTIONS
        #
        #   Resolve sources, temporary target folders, and other options 
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $OptionsObject       = Resolve-DryActionOptions -Resource $Resource -Action $Action
        $ActionType          = $OptionsObject.ActionType
        $ConfigRootPath      = $OptionsObject.ConfigRootPath
        $MetaConfigFile      = Join-Path -Path $ConfigRootPath -ChildPath 'Config.json'
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   METACONFIG
        #
        #   Open MetaConfig, resolve OU from it
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        
        $MetaConfig          = Get-DryCommentedJson -File $MetaConfigFile
        $RoleOU              = $MetaConfig.ous."$ActionType"
        If ($Null -eq $RoleOU) {
            ol -t 1 -m "Action does not contain an OU of type '$ActionType'"
            Throw "Action does not contain an OU of type '$ActionType'"
        }
        # Replace replacement patterns
        $RoleOU = Resolve-DryReplacementPattern -InputText $RoleOU -Variables $ResourceVariables
        
        # Convert the RoleOU to a distinguished name
        $RoleOU = ConvertTo-DryDistinguishedName -Name $RoleOU
        ol i @("The resolved role OU distinguishedName","$RoleOU")
        
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #   Credential
        #   Action: Get Credential for the Action
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        $Credential = Get-DryCredential -Alias "$($action.credentials.credential1)"  -GlobalConfig $GLOBAL:GlobalConfigName
        ol i @('Using Credential',"$($Credential.UserName)")

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #  Execution Type 
        # 
        #  In a Greenfield deployment, this is running an a computer outside the domain
        #  and we must remote into a domain controller to execute each configuration
        #  action. However, if this is running on a domain member in that domain, we
        #  assume that the config  may run locally. The DryAD module supports both 
        #  'Local' and 'Remote' execution. The Get-DryAdExecutionType query function
        #  tests if the prerequisites for a Local execution is there
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        Enum ExecutionType { Local; Remote }        
        [ExecutionType]$ExecutionType = Get-DryAdExecutionType -Configuration $Configuration
        ol i 'Execution Type',$ExecutionType

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        #   Resolve Active Directory Connection Point
        #
        #   Should be able to connect to the first available of an array
        #   of preferred connection points for the site that the resource belongs to 
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        $GetDryADConnectionPointParams = @{
            Resource      = $Resource 
            Configuration = $Configuration 
            ExecutionType = $ExecutionType
        }
        If ($ExecutionType -eq 'Remote') {
            $GetDryADConnectionPointParams += @{
                Credential    = $Credential
            }
        }
        
        $ActiveDirectoryConnectionPoint = Get-DryADConnectionPoint @GetDryADConnectionPointParams
        ol i @('Connection Point (Domain Controller)',$ActiveDirectoryConnectionPoint)

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #   PSSESSION
        #   Action: Create session
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        If ($ExecutionType -eq 'Remote') {
            # Create the session
            $SessionConfig = $Configuration.connections | 
            Where-Object { 
                $_.type -eq 'winrm'
            }
            If ($Null -eq $SessionConfig) {
                ol v "Unable to find 'connection' of type 'winrm' in global config"
                Throw "Unable to find 'connection' of type 'winrm' in global config"
            }

            $GetDrySessionParams =  @{
                ComputerName  = $ActiveDirectoryConnectionPoint
                Credential    = $Credential
                SessionConfig = $SessionConfig
                SessionType   = 'PSSession'
            }
            $ConfADSession = New-DrySession @GetDrySessionParams

            ol i @("Created PSSession to connection point","Session ID: $($ConfADSession.Id), State: $($ConfADSession.State)")
        }

        $MoveDryADComputerParams = @{
            ComputerName = $Resource.Name
            TargetOU     = $RoleOU
        }
        Switch ($ExecutionType) {
            'Remote' {
                $MoveDryADComputerParams += @{
                    PSSession = $ConfADSession       
                }
            }
            'Local' {
                $MoveDryADComputerParams += @{
                    DomainController = $ActiveDirectoryConnectionPoint       
                }
            }
        }

        ol i @("Moving '$($Resource.name)' computer object to","$RoleOU")
        Move-DryADComputer @MoveDryADComputerParams

        ol i "Sleeping 10 seconds before testing the new state"
        Start-Sleep -Seconds 10

        $MoveDryADComputerParams+= @{'Test'=$True}
        ol i @("Testing location of '$($Resource.name)' computer object","$RoleOU")
        
        If ((Move-DryADComputer @MoveDryADComputerParams) -eq $True) {
            ol i "Successfully completed the MoveToOU Action"
        }
        Else {
            Throw "Failed Action MoveToOU"
        }        
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
        $ConfADSession | Remove-PSSession -ErrorAction Ignore
        $VarsToRemove = @(
            'RoleOU',
            'Credential',
            'ActiveDirectoryConnectionPoint',
            'GetDrySessionParams',
            'ConfADSession',
            'MoveDryADComputerParams',
            'Test'
        )
        $VarsToRemove.ForEach({
            Remove-Variable -Name "$_" -ErrorAction Ignore
        })
        Remove-Module -Name 'dry.module.ad' -Force -ErrorAction Continue
        ol i "Action 'ad.move' is finished" -sh
    }
}

<#
Function ConvertTo-DryDistinguishedName {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String]$Name
    )
    
    # chop off any leading or trailing slashes and spaces. 
    $Name = $Name.Trim() ; $Name = $Name.Trim('/')
   
    Try {
        [String]$ConvertedName = ""
        
        If (($name -match "^ou=") -or ($name -match "^cn=")) {
            $ConvertedName = "$name"
        }
        ElseIf ($name -eq '') {
            # Empty string (probably root of domain) - return empty string then"
            $ConvertedName = $name
        }
        Else {
            # names like root/middle/leaf will be converted 
            # to ou=leaf,ou=middle,ou=root. Must assume that 
            # these are OUs, not CNs (or DCs)
            $NameArr = @($Name -split "/")
            for ($c = ($nameArr.Count -1); $c -ge 0; $c--) {  
                $ConvertedName += "OU=$($nameArr[$c]),"
            }
            # The accumulated name ends with ',', chop that off
            $ConvertedName = $ConvertedName.TrimEnd(',')
        } 
        $ConvertedName
    }
    Catch {
        ol -t 2 -m "Error converting '$Name' to distinguishedName"  
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
    }
}

Function Move-DryADComputerAccount {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [String]$ComputerName,

        [Parameter(Mandatory)]
        [String]$TargetOU,

        [Parameter(Mandatory)]
        [System.Management.Automation.Runspaces.PSSession]$PSSession,

        [Parameter(Mandatory=$false,HelpMessage="Only test and return true or false")]
        [Switch]$Test
    )
    ol -t 3 -m "Moving: '$ComputerName' to OU '$TargetOU'"

    # Is the Object already in place??
    Try {     
        $GetResult = Invoke-command -Session $PSSession -ScriptBlock { 
            Param ($ComputerName,$TargetOU); 
            
            Try {
                # Make sure ActiveDirectory module is loaded, so the AD drive is created
                If ((Get-Module | Select-Object -Property Name).Name -notcontains 'ActiveDirectory') {
                    
                    Try {
                        Import-Module -Name 'ActiveDirectory' -ErrorAction Stop
                        Start-Sleep -Seconds 4
                    }
                    Catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }
                [String]$DomainDN = (Get-ADDomain | Select-Object -Property distinguishedName).distinguishedName
                If ($TargetOU -notmatch "$DomainDN$") {
                    $TargetOU = $TargetOU + ",$DomainDN"
                }
                # The distinguishedName of the computer object that we eventually wants
                $TargetComputerDN = "CN=$ComputerName,$TargetOU"
                # Test if member, return $True if, $false if not
                If ((Get-ADComputer -Identity "$ComputerName" | Select-Object -Property distinguishedName).distinguishedName -eq "$TargetComputerDN") {
                    $True
                } 
                Else {
                    $False
                }
            }
            Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                Throw "The computer '$ComputerName' does not exist"
            }

            Catch {
                # If caught here, return the error object
                $PSCmdlet.ThrowTerminatingError($_)
            }
        } -ArgumentList $ComputerName,$TargetOU

        If ($GetResult -eq $True) {
            ol v "'$ComputerName' is already in OU '$TargetOU'"
            If ($Test) {
                Return $True
            } 
            Else {
                Return
            } 
        } 
        ElseIf ($GetResult -is [System.Management.Automation.ErrorRecord]) {
            $PSCmdlet.ThrowTerminatingError($GetResult)
        } 
        ElseIf ($GetResult -eq $False) {
            If ($Test) {
                ol v "'$ComputerName' is not in OU '$TargetOU'"
                Return $False
            } 
            Else {
                ol v "'$ComputerName' is not in OU '$TargetOU' - trying to move it"
            }
        } 
        Else {
            ol v "Unrecognized response from GetResult"
            $GetResult
            Throw "Unrecognized response from GetResult"
        }
    }
    Catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }

    # Add to the group
    If (-not $Test) {
        Try {     
            $SetResult = Invoke-command -Session $PSSession -ScriptBlock { 
                Param ($ComputerName,$TargetOU); 
                
                Try {
                    [String]$DomainDN = (Get-ADDomain | Select-Object -Property distinguishedName).distinguishedName
                    If ($TargetOU -notmatch "$DomainDN$") {
                        $TargetOU = $TargetOU + ",$DomainDN"
                    }
                    
                    # Test if member, return $True if, $false if not
                    $TargetComputer = Get-ADComputer -Identity "$ComputerName"
                    $TargetComputer | Move-ADObject -TargetPath $TargetOU
                    $true
                }
                catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
                    Throw "The computer '$ComputerName' does not exist"
                    
                }
                Catch {
                    throw $_
                }
            } -ArgumentList $ComputerName,$TargetOU
    
            If ($SetResult -eq $True) {
                ol v "'$ComputerName' was moved into OU '$TargetOU'"
                Return
            } 
            ElseIf ($SetResult -is [System.Management.Automation.ErrorRecord]) {
                $PSCmdlet.ThrowTerminatingError($GetResult)
            }  
            Else {
                ol v "Unrecognized response from GetResult"
                $SetResult
                Throw "Unrecognized response from GetResult"
            }
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }  
    }
}
#>