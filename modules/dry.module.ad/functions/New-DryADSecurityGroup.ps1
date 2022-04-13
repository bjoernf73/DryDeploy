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
Function New-DryADSecurityGroup {
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    Param (   
        [Parameter(Mandatory,
            HelpMessage = "Enter name of the group")]
        [ValidateNotNullOrEmpty()]
        [String] 
        $Name, 

        [Parameter(Mandatory,
            HelpMessage = "Enter distinguishedName of the path of the group")]
        [ValidateScript({ $_ -match "^OU=" })]
        [String] 
        $Path, 
        
        [Parameter(Mandatory, HelpMessage = "Enter a description for the group")]
        [ValidateNotNullOrEmpty()]
        [String] 
        $Description, 

        [Parameter(HelpMessage = "Active Directory group type. Must be 'DomainLocal', 'Global' or 'Universal'")]
        [ValidateSet("DomainLocal", "Global", "Universal")]
        [String] 
        $Type = "DomainLocal", 

        [Parameter(HelpMessage = "Group category. Must be 'Security' or 'Distribution'. Defaults to security.")]
        [String] 
        $GroupCategory = "Security",

        [Parameter(ParameterSetName = 'Remote',
            HelpMessage = "PSSession to run the script blocks in")]
        [PSSession] 
        $PSSession,

        [Parameter(Mandatory, ParameterSetName = 'Local',
            HelpMessage = "For 'Local' sessions, specify the Domain Controller to use")]
        [String] 
        $DomainController
    )
    # Details to the debug stream
    ol d @("Creating Group", $Name)
    ol d @("Group Path", $Path)
    ol d @("Group Type", $Type)
    ol d @("Group Category", $GroupCategory)
    ol d @("Group Description", $Description)
    <#
        If executing on a remote session to a DC, use localhost as  
        server. If not, the $DomainController param is required
    #>
    If ($PSCmdlet.ParameterSetName -eq 'Remote') {
        $Server = 'localhost'
        ol d @('Session Type', 'Remote')
        ol d @('Remoting to Domain Controller', "$($PSSession.ComputerName)")
    }
    Else {
        $Server = $DomainController
        ol d @('Session Type', 'Local')
        ol d @('Using Domain Controller', "$Server")
    }
    
    try {
        $GetArgumentList = @($Name, $Server)
        $GetParams = @{
            ScriptBlock  = $DryAD_SB_SecurityGroup_Get
            ArgumentList = $GetArgumentList
        }
        If ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $GetParams += @{
                Session = $PSSession
            }
        }
        $GetResult = Invoke-Command @GetParams

        Switch ($GetResult) {
            $True {
                ol v @("The AD Group exists already", $Name)
                ol s 'Group exists already'
                Return
            }
            $False {
                ol v @("The Group does not exist, and must be created", $Name)
            }
            Default {
                ol 2 @("Error trying to get Group", "$Name")
                Throw $GetResult
            }
        } 
    }
    Catch {
        ol 2 @("Failed trying to get group", "$Name") 
        Throw $_
    }
    
    If ($GetResult -eq $False) {
        $SetArgumentList = @($Name, $Path, $Description, $GroupCategory, $Type, $Server)
        $SetParams = @{
            ScriptBlock  = $DryAD_SB_SecurityGroup_Set
            ArgumentList = $SetArgumentList
        }
        If ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $SetParams += @{
                Session = $PSSession
            }
        }
        $SetResult = Invoke-Command @SetParams
        
        Switch ($SetResult) {
            $True {
                ol s "Group was created"
                ol v @("AD Group was created", $Name)
            }
            Default {
                ol 2 @('Error creating AD Group', $Name)
                ol f "Group was not created"
                Throw $SetResult
            }
        }
    }
}
