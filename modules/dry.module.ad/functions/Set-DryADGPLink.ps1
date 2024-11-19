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
function Set-DryADGPLink {
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    param (
        [Parameter(Mandatory, HelpMessage = "Object containing description av an OU and set of ordered GPLinks")]
        [PSObject]
        $GPOLinkObject,

        [Parameter(Mandatory)]
        [string]
        $DomainFQDN,

        [Parameter(Mandatory)]
        [string]
        $DomainDN,

        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [PSSession]
        $PSSession,

        [Parameter(Mandatory, ParameterSetName = 'Local',
            HelpMessage = "For 'Local' sessions, specify the Domain Controller to use")]
        [string]
        $DomainController
    )

    if ($PSCmdLet.ParameterSetName -eq 'Remote') {
        $Server = 'localhost'
        ol v @('Session Type', 'Remote')
        ol v @('Remoting to Domain Controller', "$($PSSession.ComputerName)")
    }
    else {
        $Server = $DomainController
        ol v @('Session Type', 'Local')
        ol v @('Using Domain Controller', "$Server")
    }
  
    # Add the domainDN to $OU if not already done
    if ($GPOLinkObject.Path -notmatch "$DomainDN$") {
        if (($GPOLinkObject.Path).Trim() -eq '') {
            # The domain root
            $GPOLinkObject.Path = $DomainDN
        }
        else {
            $GPOLinkObject.Path = $GPOLinkObject.Path + ',' + $DomainDN
        }
    }
    ol v @('Linking GPOs to', "$($GPOLinkObject.Path)") 

    try {
        # Order the GPOLinks by its 'order'-property
        $GPOLinkObject.gplinks = $GPOLinkObject.gplinks | Sort-Object -Property 'order'
       
        $GetCurrentLinksArgumentList = @(
            $GPOLinkObject.Path,
            $Server
        )

        $GetInvokeParams = @{
            ScriptBlock  = $DryAD_SB_GPLink_Get
            ArgumentList = $GetCurrentLinksArgumentList
        }
        if ($PSCmdLet.ParameterSetName -eq 'Remote') {
            $GetInvokeParams += @{
                Session = $PSSession
            }
        }
        $CurrentLinks = Invoke-Command @GetInvokeParams
        
        # If $CurrentLinks[1] is an empty string, the remote command succeeded
        if ($CurrentLinks[1] -eq '') {
            if ($CurrentLinks[0].count -eq 0) {
                ol v 'No GPOs are currently linked to', "$($GPOLinkObject.Path)"
            }
            else {
                [Array]$CurrentLinkNames = $CurrentLinks[0]
                $CurrentLinkNames.Foreach( { ol v 'Current Link', "$_" })
            }
        } 
        else {
            throw $CurrentLinks[1]
        }

        <#
            Create the current link table, which is a list of objects with properties
            .Name     = "My Awesome GPO - v1.0.3"
            .BaseName = "My Awesome GPO - "
            .Version  = "v1.0.3"
        #>
        [System.Collections.Generic.List[PSObject]]$CurrentLinkTable = @()
        foreach ($LinkName in $CurrentLinkNames) {
            Switch -regex ($LinkName) {
                # ex V1.45.9
                "v[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}$" {
                    $LinkBaseName = ($LinkName).TrimEnd($($matches[0]))
                    #$LinkVersion = $matches[0]
                    $v = $matches[0]
                    $LinkVersion = [system.version]"$($v.Trim('V').Trim('v'))"
                }
                # ex v3r9 (like DoD Baselines)
                "v[0-9]{1,5}r[0-9]{1,5}$" {
                    $LinkBaseName = ($LinkName).TrimEnd($($matches[0]))
                    #$LinkVersion = $matches[0]
                    $v = $matches[0]
                    $LinkVersion = [system.version]"$($(($v -isplit 'v') -isplit 'r')[1]).$($(($v -isplit 'v') -isplit 'r')[2])"
                }
                # no versioning
                default {
                    $LinkBaseName = $LinkName
                    $LinkVersion = ''
                }
            }
            $CurrentLinkTable += New-Object -TypeName PSObject -Property @{
                Name     = $LinkName
                BaseName = $LinkBaseName
                Version  = $LinkVersion
            }
            Remove-Variable -Name LinkBaseName, LinkVersion -ErrorAction Stop
        }

        # Loop through all links
        foreach ($GPLink in $GPOLinkObject.GPLinks) {
            try {
                # Get the basename of the GPO (versioning trimmed off). 
                Switch -regex ($GPLink.Name) {
                    # ex V1.45.9
                    "v[0-9]{1,5}\.[0-9]{1,5}\.[0-9]{1,5}$" {
                        $BaseName = ($GPLink.Name).TrimEnd($($matches[0]))
                        #$Version = $matches[0]
                        $v = $matches[0]
                        $Version = [system.version]"$($v.Trim('V').Trim('v'))"
                    }
                    # ex v3r9 (like DoD Baselines)
                    "v[0-9]{1,5}r[0-9]{1,5}$" {
                        $BaseName = ($GPLink.Name).TrimEnd($($matches[0]))
                        #$Version = $matches[0]
                        $v = $matches[0]
                        $Version = [system.version]"$($(($v -isplit 'v') -isplit 'r')[1]).$($(($v -isplit 'v') -isplit 'r')[2])"
                    }
                    # no versioning
                    default {
                        $BaseName = $GPLink.Name
                        $Version = ''
                    }
                }
                $GPLink | Add-Member -MemberType NoteProperty -Name 'BaseName' -Value $BaseName
                $GPLink | Add-Member -MemberType NoteProperty -Name 'Version' -Value $Version 

                # Links get enabled by default. Override if explicitly set to disabled in GPLink object
                # Accept boolean $false as well as 'No'. The GP-cmdlets uses 'Yes' and 'No'
                $LinkEnabled = 'Yes'
                if (
                    ($GpLink.LinkEnabled -eq 'No') -or 
                    ($GpLink.LinkEnabled -eq $false)
                ) {
                    $LinkEnabled = 'No'
                }
                
                # Enforce if explicitly set in the GPLink object
                $Enforced = 'No'
                if (
                    ($GpLink.Enforced -eq 'Yes') -or 
                    ($GpLink.Enforced -eq $true)
                ) {
                    $Enforced = 'Yes'
                }

                # Test if there is a match for this GPO name in $CurrentLinkTable
                $CurrentlyLinkedMatch = $CurrentLinkTable | Where-Object { 
                    $_.Name -eq $GPLink.Name 
                }
                
                if ($CurrentlyLinkedMatch) {
                    ol v "The GPO '$($GPLink.Name)' is already linked to '$($GPOLinkObject.Path)'"

                    # However, run Set-GPLink to enforce Order, Enforce and LinkEnabled
                    $SetLinkArgumentList = @(
                        $GPOLinkObject.Path,
                        $GPLink.Name,
                        $GPLink.Order,
                        $LinkEnabled,
                        $Enforced,
                        $Server
                    )
                    $InvokeSetLinkParams = @{
                        ScriptBlock  = $DryAD_SB_GPLink_Set
                        ArgumentList = $SetLinkArgumentList
                        ErrorAction  = 'Stop'
                    }

                    if ($PSCmdLet.ParameterSetName -eq 'Remote') {
                        $InvokeSetLinkParams += @{
                            Session = $PSSession
                        }
                    }
                    ol i @('GPO', "$($GPLink.Name)")
                    $SetLinkRet = Invoke-Command @InvokeSetLinkParams
                    
                    if ($SetLinkRet[0] -eq $true) {
                        ol v "Successfully updated GPlink properties for '$($GPLink.Name)' on $($GPOLinkObject.Path)"
                        ol s "Link updated"
                    }
                    else {
                        ol f "Link updated"
                        throw $SetLinkRet[1]
                    }

                    # Jump to next link
                    Continue
                }

                # If there are lower-versioned GPOs linked, those links should be removed. If 
                # there are higher-versioned GPOs linked, throw an error
                $CurrentlyLinkedBaseMatches = @($CurrentLinkTable | Where-Object { $_.BaseName -eq $GPLink.BaseName })
                if ($CurrentlyLinkedBaseMatches) {
                    $Unlink = @()
                    foreach ($BaseNameMatch in $CurrentlyLinkedBaseMatches) {
                        if ($BaseNameMatch.Version -lt $GPLink.Version) {
                            ol v "The lower versioned GPO '$($BaseNameMatch.Name)' will be unlinked"
                            $Unlink += $BaseNameMatch.Name
                        } 
                        elseif ($BaseNameMatch.Version -gt $GPLink.Version) {
                            ol w "The higher versioned GPO '$($BaseNameMatch.Name)' is already linked"
                            throw "The higher versioned GPO '$($BaseNameMatch.Name)' is already linked"
                        }
                    }
                    # If any items in $Unlink, add the array as property 'Unlink' 
                    if ($Unlink.Count -gt 0) {
                        $GPLink | Add-Member -MemberType NoteProperty -Name 'Unlink' -Value $Unlink 
                    }

                }

                # Remove existing GPLink, if Links for lower versioned GPOs exist
                foreach ($LinkToRemove in $GPLink.Unlink) {
                    ol i @('Unlinking', "$LinkToRemove")

                    $RemoveLinkArgumentList = @($GPOLinkObject.Path, $LinkToRemove, $Server)
                    $InvokeRemoveLinkParams = @{
                        ScriptBlock  = $DryAD_SB_GPLink_Remove
                        ArgumentList = $RemoveLinkArgumentList
                    }
                    if ($PSCmdLet.ParameterSetName -eq 'Remote') {
                        $InvokeRemoveLinkParams += @{
                            Session = $PSSession
                        }
                    }
                    $RemoveLinkRet = Invoke-Command @InvokeRemoveLinkParams 
                    
                    if ($RemoveLinkRet[0] -eq $true) {
                        ol s "Successfully removed link for GPO '$LinkToRemove'"
                    }
                    else {
                        throw $RemoveLinkRet[1]
                    }
                }

                # Finally, we're ready to set the new GPO Link
                ol i @('GPO', "$($GPLink.Name)")

                $NewLinkArgumentList = @(
                    $GPOLinkObject.Path,
                    $GPLink.Name,
                    $GPLink.Order,
                    $LinkEnabled,
                    $Enforced,
                    $Server
                )

                $InvokeNewLinkParams = @{
                    ScriptBlock  = $DryAD_SB_GPLink_New
                    ArgumentList = $NewLinkArgumentList
                }

                if ($PSCmdLet.ParameterSetName -eq 'Remote') {
                    $InvokeNewLinkParams += @{
                        Session = $PSSession
                    }
                }
                $NewLinkRet = Invoke-Command @InvokeNewLinkParams
                
                if ($NewLinkRet[0] -eq $true) {
                    ol s 'GPO Linked'
                }
                else {
                    ol f 'GPO Link failed'
                    throw $NewLinkRet[1]
                }
            }
            catch {
                $PSCmdLet.ThrowTerminatingError($_)
            }
            finally {
                # remove variables 
                @('CurrentlyLinkedMatch',
                    'BaseName',
                    'Version',
                    'CurrentlyLinkedBaseMatches',
                    'Unlink',
                    'LinkEnabled',
                    'Enforced').foreach({
                        Remove-Variable -Name $_ -ErrorAction Ignore
                    })
            }
        }
    }
    catch {
        $PSCmdLet.ThrowTerminatingError($_)
    }
}
