Using Namespace System.Management.Automation.Runspaces
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

Function Remove-DryADGPLink {
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    Param (
        [Parameter(Mandatory, HelpMessage = "Object containing description ov an OU and set of ordered GPLinks")]
        [PSObject]
        $GPOLinkObject,

        [Parameter(Mandatory)]
        [String]
        $DomainFQDN,

        [Parameter(Mandatory)]
        [String]
        $DomainDN,

        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [PSSession]
        $PSSession,

        [Parameter(Mandatory, ParameterSetName = 'Local',
            HelpMessage = "For 'Local' sessions, specify the Domain Controller to use")]
        [String]
        $DomainController
    )

    If ($PSCmdLet.ParameterSetName -eq 'Remote') {
        $Server = 'localhost'
        ol v @('Session Type', 'Remote')
        ol v @('Remoting to Domain Controller', "$($PSSession.ComputerName)")
    }
    Else {
        $Server = $DomainController
        ol v @('Session Type', 'Local')
        ol v @('Using Domain Controller', "$Server")
    }
  
    # Add the domainDN to $OU if not already done
    If ($GPOLinkObject.Path -notmatch "$DomainDN$") {
        If (($GPOLinkObject.Path).Trim() -eq '') {
            # The domain root
            $GPOLinkObject.Path = $DomainDN
        }
        Else {
            $GPOLinkObject.Path = $GPOLinkObject.Path + ',' + $DomainDN
        }
    }
    ol v @('Linking GPOs to', "$($GPOLinkObject.Path)") 

    try {
        $RemoveLinkArgumentList = @($GPOLinkObject.Path, $LinkToRemove, $Server)
        $InvokeRemoveLinkParams = @{
            ScriptBlock  = $DryAD_SB_GPLink_Remove
            ArgumentList = $RemoveLinkArgumentList
        }
        If ($PSCmdLet.ParameterSetName -eq 'Remote') {
            $InvokeRemoveLinkParams += @{
                Session = $PSSession
            }
        }
        $RemoveLinkRet = Invoke-Command @InvokeRemoveLinkParams 
        
        If ($RemoveLinkRet[0] -eq $True) {
            ol s "Successfully removed link for GPO '$LinkToRemove'"
        }
        Else {
            Throw $RemoveLinkRet[1]
        }
    }
    Catch {
        $PSCmdLet.ThrowTerminatingError($_)
    }
}














