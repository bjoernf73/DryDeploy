Using NameSpace System.Management.Automation.Runspaces
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
function Set-DryADAccessRule {
    [CmdletBinding(DefaultParameterSetName = 'Local')] 
    param ( 
        [Parameter(HelpMessage = "Name of user to delegate rights to. 
        Never used by DryDeploy, since rights are always delegated to groups")]
        [String]
        $User,

        [Parameter(HelpMessage = "Name of group to delegate rights to")]
        [String]
        $Group,    
    
        [Parameter(Mandatory,
            HelpMessage = "DistinguisheName of container object (ou or cn) to set rights on")]
        [String]
        $Path,

        [Parameter(Mandatory,
            HelpMessage = "Array of Active Directory standard or extended rights")]
        [String[]]
        $ActiveDirectoryRights,
        
        [Parameter(Mandatory,
            HelpMessage = "Access Control Type, either 'Allow' or 'Deny'.")]
        [ValidateSet("Allow", "Deny")]
        [String]
        $AccessControlType, 
        
        [Parameter(HelpMessage = "Inheritance")]
        [ValidateSet("All", "Children", "Descendents", "SelfAndChildren", "None")]
        [String]
        $ActiveDirectorySecurityInheritance, 

        [Parameter(HelpMessage = "The AD object type that the right(s) applies to. 
        Like 'user','computer' or 'organizationalunit', or any other AD object type")]
        [String]
        $ObjectType, 
        
        [Parameter(HelpMessage = "The object type by name that should inherit the right(s).")]
        [String]
        $InheritedObjectType,

        [Parameter(Mandatory, ParameterSetName = 'Remote',
            HelpMessage = "PSSession to run the script blocks in")]
        [PSSession] 
        $PSSession,

        [Parameter(Mandatory, ParameterSetName = 'Local',
            HelpMessage = "For 'Local' sessions, specify the Domain Controller to use")]
        [String] 
        $DomainController
    )

    try {
        if ($Group -and (-not $User)) {
            $TargetName = $Group
            $TargetType = 'group'
        }
        elseif ($User -and (-not $Group)) {
            $TargetName = $User
            $TargetType = 'user'
        }
        else {
            throw "Specify either a Group or a User to delegate permissions to - and not both"
        }
        
        ol v @('Path', "$Path")
        ol v @('TargetName', "$TargetName")
        ol v @('TargetType', "$TargetType")
        

        if ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $Server = 'localhost'
            $ExecutionType = 'Remote'
            ol v @('Session Type', 'Remote')
            ol v @('Remoting to Domain Controller', $PSSession.ComputerName)
        }
        else {
            $Server = $DomainController
            $ExecutionType = 'Local'
            ol v @('Session Type', 'Local')
            ol v @('Using Domain Controller', $Server)
        }

        # Since parameters cannot be splatted, or named in -Argumentslist, make sure all exists
        if (-not $ObjectType) { [String]$ObjectType = '' }
        if (-not $InheritedObjectType) { [String]$InheritedObjectType = '' }
        if (-not $ActiveDirectorySecurityInheritance) { [String]$ActiveDirectorySecurityInheritance = '' }
            
        $ArgumentList = @(
            $Path,
            $TargetName,
            $TargetType,
            $ActiveDirectoryRights,
            $AccessControlType,
            $ObjectType,
            $InheritedObjectType,
            $ActiveDirectorySecurityInheritance,
            $ExecutionType,
            $Server
        )
        $InvokeParams = @{
            ScriptBlock  = $DryAD_SB_ADAccessRule_Set
            ArgumentList = $ArgumentList
        }
        if ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $InvokeParams += @{
                Session = $PSSession
            }
        }
        $return = $Null; $return = Invoke-Command @InvokeParams

        # Send every string in $Return[0] to Debug via Out-DryLog
        foreach ($ReturnString in $Return[0]) {
            ol d "$ReturnString"
        }
        
        # Test the ReturnValue in $Return[1]
        if ($Return[1] -eq $true) {
            ol s 'AD right set'
            ol v "Successfully configured AD right"
            $true
        } 
        else {
            ol f 'AD right not set'
            ol w "Failed to configure AD right"
            if ($Null -ne $Return[2]) {
                throw ($Return[2]).ToString()
            } 
            else {
                throw "ReturnValue false, but no ErrorRecord returned - check debug"
            }
        }  
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
