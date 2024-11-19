using Namespace System.Collections.Generic
using Namespace System.Collections

class Resources {
    [ArrayList]$Resources

    # create an instance
    Resources ([PSCustomObject]$Configuration,[PSCustomObject]$ConfigCombo, [bool]$Interactive) {
        $This.Resources = [ArrayList]::New()
        switch ($Interactive) {
            $false { 
                # Loop through the resources in the build
                foreach ($Resource in $Configuration.CoreConfig.resources | Where-Object { $_.role -in @($Configuration.Build.roles.role) }) {
                    $Resource = [Resource]::New(
                        $Resource.Name,
                        $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $Resource.role -Property 'role_short_name'),
                        $Resource.Role,
                        $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $Resource.role -Property 'base_config'),
                        $Configuration.Paths.BaseConfigDirectory,
                        $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $Resource.role -Property 'description'),
                        $Resource.Network,
                        $ConfigCombo,
                        $Configuration,
                        $Resource.Options
                    )
                    $This.Resources += $Resource
                }
             }
            $true {
                do {
                    [System.ConsoleColor]$SelectionColor = 'DarkGreen'
                    do {
                        $AddAnotherResource = $true
                        $HappyWithTheSelection = $false
                        $sSelected = $null
                        $sSelected = [PSCustomObject]@{
                            Role   = $null
                            Short  = $null
                            Name   = $null
                            Site   = $null
                            Subnet = $null
                            IP     = $null
                        }
                        $sSite = [PSCustomObject]@{
                            site        = $null
                            subnet_name = $null
                            ip_address  = $null
                            net         = $null
                            mask        = $null
                            dns         = $null
                        }
                        
                        <#
                            Role: Get Available Roles, display the list for the 
                            user, prompt for and get selection  
                        #>
                        #ol i "Select role" -sh
                        #ol i " "
                        $iRolesToSelectFrom = [ArrayList]::New()
                        foreach ($iRole in $Configuration.build.roles) {
                            $iIndex              = $iRole.order
                            $iRoleName           = $iRole.role
                            $iShort              = $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $iRoleName -Property 'role_short_name')
                            $iDescription        = $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $iRoleName -Property 'description')
                            $iRolesToSelectFrom += [PSCustomObject]@{index=$iIndex;role=$iRoleName;short=$iShort;description=$iDescription}
                        }
                        $iRolesStrings = ($($iRolesToSelectFrom | Out-String).Split("`r`n")) | Where-Object { $_.Trim() -ne ''}
                        foreach ($iString in $iRolesStrings) {
                            ol i "$iString"
                        }
                        ol i " "
                        $GetDryInputParams = @{
                            Prompt             = "Enter index of a role"
                            PromptChoiceString = "$($Configuration.build.roles.order)"
                            #Description        = "The list above are roles that you may select from in interactive mode. You may select a different module (.\DryDeploy.ps1 -ModuleConfig ..\path\to\config) if the role you are looking for is not in the list"
                            FailedMessage      = "You need to select the index of the role, i.e. one of '$($Configuration.build.roles.order)' or 'q' to quit"
                            ValidateSet        = $Configuration.build.roles.order
                        }
                        [int]$sRoleIndex = Get-DryInput @GetDryInputParams
                        if ($sRoleIndex -in $Configuration.build.roles.order) {
                            $sSelected.Role  = ($iRolesToSelectFrom | Where-Object { $_.index -eq $sRoleIndex}).role
                            $sSelected.Short = ($iRolesToSelectFrom | Where-Object { $_.index -eq $sRoleIndex}).short
                            #$sSelected.Short = Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $sSelected.Role -Property 'role_short_name'
                        }
                        else {
                            break
                        }
                        #ol i " "
                        #ol i -obj $sSelected -msgtitle "Your Selections" -Fore $SelectionColor
                        

                        <#
                            Short: A short name of the role. The short (short_role_name) should be used in the resource name, and 
                            for a domain member, the server may be separated from other roles in an OU with the same name as the
                            short.  
                        #>
                        #ol i "Enter short (short name of role)" -sh
                        #ol i " "
                        $iRolesToSelectFrom = $null
                        $iRolesStrings = $null
                        [scriptblock]$ValidateShortRoleNameScript =  {
                            param($DryInput)
                            $DryInput = $DryInput.Trim()
                            ($DryInput -is [string]) -and 
                            ($DryInput.length -ge 2) -and
                            ($DryInput.length -le 8) -and
                            ($DryInput -notmatch "\d$") -and
                            ($DryInput -notmatch "^\d")
                        }
                        
                        ol i " "
                        $GetDryInputParams = @{
                            Prompt               = "Customize the Short (2-8 characters), or ENTER for default ('$($sSelected.Short)')"
                            PromptChoiceString   = ""
                            #Description          = "The list above is an example of roles and corresponding short role names for inspiration"
                            FailedMessage        = "The short role name should be 2-8 chars, not contain special chars but plain letters, and not start or end with a number. The role short name is significant it you have an Active Directory that separates roles into OU's based on the role short name. If you don't, just accept the defult"
                            ValidateScript       = $ValidateShortRoleNameScript
                            ValidateScriptParams = @()
                            DefaultValue         = "$($sSelected.Short)"
                        }
                        [string]$sShortRoleName = Get-DryInput @GetDryInputParams
                        if (-not $sShortRoleName) {
                            break
                        }

                        $sSelected.Short = $sShortRoleName
                        #ol i " "
                        #ol i -obj $sSelected -msgtitle "Your Selections" -Fore $SelectionColor
                        #ol i " "

                        <#
                            Subnet: Get Available Sites and Subnets, display the list for 
                            the user, prompt for and get selection found in 
                            CoreConfig.network.sites[n].subnets 
                        #>
                        #ol i "Select network" -sh
                        #ol i " "
                        $iSubnetsToSelectFrom = [ArrayList]::New()
                        $iSubnetsIndex = 0
                        $iSubnetsIndexArray = $null; $iSubnetsIndexArray = @()
                        foreach ($iSite in $Configuration.CoreConfig.network.sites) {
                            foreach ($iSubnet in $iSite.subnets) {
                                $iSubnetsIndex++
                                $iSubnetsIndexArray   += $iSubnetsIndex
                                $iSubnetsToSelectFrom += [PSCustomObject]@{
                                    index       = $iSubnetsIndex;
                                    site        = $iSite.name;
                                    subnet_name = $iSubnet.name;
                                    ip_subnet   = $iSubnet.ip_subnet;
                                    subnet_mask = $iSubnet.subnet_mask;
                                    dns         = $iSubnet.dns
                                }
                            }
                        }
            
                        $iSubnetsStrings = ($($iSubnetsToSelectFrom | Format-Table * | Out-String).Split("`r`n")) | Where-Object { $_.Trim() -ne ''}
                        foreach ($iString in $iSubnetsStrings) {
                            ol i "$iString"
                        }
                        ol i " "
                        $GetDryInputParams = @{
                            Prompt             = "Enter index of a subnet"
                            PromptChoiceString = "$iSubnetsIndexArray"
                            #Description        = "The list above are subnets that you may select from. You may select a different environment (.\DryDeploy.ps1 -EnvConfig ..\path\to\config) if the subnet you are looking for is not in the list"
                            FailedMessage      = "You need to select the index of the subnet, i.e. one of '$iSubnetsIndexArray'"
                            ValidateSet        = $iSubnetsIndexArray
                        }
                        [int]$sSiteIndex = Get-DryInput @GetDryInputParams
                        if ($sSiteIndex) {
                            [PSCustomObject]$sSite = ($iSubnetsToSelectFrom | Where-Object { $_.index -eq $sSiteIndex}) | Select-Object -Property site,subnet_name,ip_subnet,subnet_mask,dns
                        }
                        else {
                            break
                        }
                        $sSubnetMaskBits = Convert-DryUtilsIpAddressToMaskLength -IPAddress $sSite.subnet_mask
                        $sSubnetCidrString = "$($sSite.ip_subnet)/$sSubnetMaskBits"
                        $sSelected.Site   = $sSite.site
                        $sSelected.Subnet = $sSubnetCidrString
                        #ol i -obj $sSelected -msgtitle "Your Selections" -Fore $SelectionColor
                        #ol i " "
            
                        <#
                            IP: Get the IP of the resource
                        #>
                        #ol i "Enter IP of the resource" -sh
                        #ol i " "
                        [scriptblock]$ValidateScript =  {
                            param(
                                $sSiteNet,
                                $sSiteMask,
                                $DryInput
                            )
                            ($DryInput -eq 'dhcp') -or (Invoke-PSipcalc -NetworkAddress "$($sSiteNet)/$($sSiteMask)" -Contains "$DryInput")
                        }
                        $GetDryInputParams = @{
                            Prompt               = "Enter IP in the $sSubnetCidrString network"
                            PromptChoiceString   = "<IP>, 'dhcp'"
                            #Description          = "Enter an ipv4 address in the subnet you've selected, or simply enter 'dhcp'"
                            FailedMessage        = "You need to enter a proper ip in the correct subnet"
                            ValidateScript       = $ValidateScript
                            ValidateScriptParams = @($sSite.ip_subnet,$sSite.subnet_mask)
                        }
                        [string]$sResourceIP = Get-DryInput @GetDryInputParams
                        $sSelected.IP = $sResourceIP
                        $sSite | Add-Member -MemberType NoteProperty -Name 'ip_address' -Value $sResourceIP
                        #ol i -obj $sSelected -msgtitle "Your Selections" -Fore $SelectionColor
                        #ol i " "
            
                        <#
                            Name: Get the name of the resource
                        #>
                        #ol i "Enter a resource name" -sh
                        #ol i " "
                        <#
                            $iResourcesExample = $Configuration.CoreConfig.resources | Select-Object -Property name,role
                            $iResourcesStrings = ($($iResourcesExample | Out-String).Split("`r`n")) | Where-Object { $_.Trim() -ne ''}
                            foreach ($iString in $iResourcesStrings) {
                                ol i "$iString"
                            }
                            ol i " "
                        #>
                        #ol i -obj $sSelected -msgtitle "Your Selections" -Fore $SelectionColor
                        $GetDryInputParams = @{
                            Prompt        = "Enter name of the resource"
                            #Description   = "If you see a list above, they are names and corresponding roles of resources specified in your current environment config. If the list is empty, you probably clickops eveything, don't you? If you do see some names there, they are only listed here to inspire you to make the slightest effort to approximate the current naming convention used in your environment. If no such convention is obvious, well...that's on you."
                            FailedMessage = "You need to enter a name for your resource"
                            ValidateScript = {param($DryInput); (($DryInput -ne '') -and ($null -ne $DryInput))}
                        }
                        [string]$sResourceName = Get-DryInput @GetDryInputParams
                        if (!($sResourceName)) {
                            break
                        }
                        $sSelected.Name = $sResourceName
                        ol i -obj $sSelected -msgtitle "Your Selection" -Fore $SelectionColor
                        $GetDryInputParams = @{
                            Prompt             = "Submit to plan?"
                            PromptChoiceString = "y(es),  n(o)"
                            #Description        = "Happy with the selection? Select 'yes' ('y') or 'no' ('n')"
                            FailedMessage      = "You need to enter 'yes' ('y') or 'no' ('n') or 'q' to quit"
                            ValidateSet        = @('y','yes','n','no')
                        }
                        $sHappyWithSelection = $null
                        [string]$sHappyWithSelection = Get-DryInput @GetDryInputParams
                        if ($sHappyWithSelection -in 'y','yes') {
                            $HappyWithTheSelection = $true
                        }
            
                    }
                    while ($HappyWithTheSelection -eq $false)
                    
                    if ($HappyWithTheSelection) {
                        $This.Resources += [Resource]::New(
                            $sSelected.Name,
                            $sSelected.Short,
                            $sSelected.Role,
                            $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $sSelected.Role -Property 'base_config'),
                            $Configuration.Paths.BaseConfigDirectory,
                            $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $sSelected.Role -Property 'description'),
                            $sSite,
                            $ConfigCombo,
                            $Configuration,
                            $null
                        )
                    }

                    ol i " "
                    $GetDryInputParams = @{
                        Prompt             = "Add another resource to plan?"
                        PromptChoiceString = "y(es), n(o)"
                        FailedMessage      = "You need to enter 'yes' ('y') or 'no' ('n') or 'q' to quit"
                        ValidateSet        = @('y','yes','n','no')
                    }
                    $AddAnotherResource = $true
                    [string]$AddAnotherResponse = Get-DryInput @GetDryInputParams
                    if ($AddAnotherResponse -in 'n','no') {
                        $AddAnotherResource = $false
                    }
                }
                while ($true -eq $AddAnotherResource)
            }
        }
        
        $This.DoOrder($Configuration.CoreConfig.Network,$Configuration.Build)
        $This.AddActionGuids()
    }

    [Void] AddActionGuids () {
        $This.Resources.foreach({
            $ResourceOrder = $_.ResourceOrder
            foreach ($Action in $_.ActionOrder) {
                $ActionOrder = $Action.order
                $Action | Add-Member -MemberType NoteProperty -Name 'Action_Guid' -Value ($This.NewActionGuid($ResourceOrder,$ActionOrder))
            }
        })
    } 

    [string] NewActionGuid([int]$ResourceOrder,[int]$ActionOrder) { 
        return [string]('{0:d4}' -f $ResourceOrder) + [string]('{0:d4}' -f $ActionOrder) + '0000-' + ((New-Guid).Guid)
    }


    [string] GetPreviuosDependencyActionGuid (
        [string]$Action_Guid 
    ) {
        [int]$ResourceOrder = $Action_Guid.Substring(0,4)
        [int]$ActionOrder = $Action_Guid.Substring(4,4)
        $ActionOrder--
        $Resource = $This.Resources | Where-Object { 
            $_.ResourceOrder -eq $ResourceOrder
        }
        $Action = $Resource.ActionOrder | Where-Object {
            $_.Order -eq $ActionOrder
        }

        if ($null -eq $Action) {
            throw "Unable to find previous Action (Resource: $ResourceOrder, Action $ActionOrder)"
        }

        # Only return the GUID-part - that will be matched to the previous Action
        # when that Action eventually get's into to Plan
        return ($Action.Action_Guid).SubString(12)
    }

    # Find first Action in plan and return true if it matches $ActionSpec
    [Bool] IsThisFirstActionInPlan ([string]$ActionGuid) {
        
        # Loop though Resources using their ResourceOrder-property
        :ResourceLoop for ($ResourceOrder = 1; $ResourceOrder -le $This.Resources.Count; $ResourceOrder++) {
            $CurrentResource = $This.Resources | 
            Where-Object { 
                $_.ResourceOrder -eq $ResourceOrder
            }
            # Loop through Actions using their Order-property
            for ($ActionOrder = 1; $ActionOrder -le $CurrentResource.ActionOrder.Count; $ActionOrder++) {
                $CurrentAction = $CurrentResource.ActionOrder | 
                Where-Object { 
                    $_.Order -eq $ActionOrder
                }
                # As soon as we meet an Action without an explicit dependency, it is considered the first Action
                if ($null -eq $CurrentAction.depends_on) {
                    $FirstActionGuid = $CurrentAction.Action_Guid
                    Break ResourceLoop
                }
            }
        }

        if ( $null -eq $FirstActionGuid ) {
            throw "No first Action in Resolved Resurces found"
        }
        elseif ( $FirstActionGuid -eq $ActionGuid ) {
            Remove-Variable -Name FirstActionGuid -ErrorAction Ignore
            return $true
        }
        else {
            Remove-Variable -Name FirstActionGuid -ErrorAction Ignore
            return $false
        }
    }

    [Void] DoOrder ([PSObject]$Network,[PSObject]$Build) {
        
        [array]$Sites = @(($Network.Sites).Name)
        [array]$RoleOrder  = @($Build.roles)
        [string]$OrderType = $Build.order_type

        if ($OrderType -notin @('site','role')) {
            [string]$OrderType = 'role'
        }

        $ResourceCount     = 0
        $ResolvedResources = @()

        switch ($OrderType) {
            'site' {
                # Resources are deployed site by site. Within  
                # the site, the resource order will be followed
                foreach ($Site in $Sites) {
                    for ($RoleCount = 1; $RoleCount -le $RoleOrder.count; $RoleCount++) {
            
                        Remove-Variable -Name BuildRole -ErrorAction Ignore
                        $BuildRole = $null
                        $BuildRole = $RoleOrder | Where-Object {
                            $_.order -eq $RoleCount
                        }
            
                        if ($BuildRole -is [array]) {
                            throw "Multiple Roles in the Build with order $RoleCount"
                        }
                        elseif ($null -eq $BuildRole) {
                            throw "No Roles in the Build with order $RoleCount"
                        }
    
                        $BuildRoleName = $BuildRole.Role
    
                        Remove-Variable -Name 'CurrentSiteAndConfopResources' -ErrorAction Ignore
                        $CurrentSiteAndConfopResources = @()
                        $This.Resources | foreach-Object {
                            if (($_.Network.Site -eq $Site) -and ($_.Role -eq $BuildRoleName)) {
                                $CurrentSiteAndConfopResources += $_
                            }
                    
                        }
                        if ($CurrentSiteAndConfopResources) {
                            # Multiple resources of the same Role at the same site will be ordered alphabetically by name
                            $CurrentSiteAndConfopResources = $CurrentSiteAndConfopResources | Sort-Object -Property Name
                            foreach ($CurrentSiteAndConfopResource in $CurrentSiteAndConfopResources) {
                                $ResourceCount++
                                $CurrentSiteAndConfopResource.ResourceOrder =  $ResourceCount 
                                $ResolvedResources += $CurrentSiteAndConfopResource
                            }
                        } 
                    }  
                }
            }
            'role' {
                # Resources are deployed according to the resource order
                # in the Build regardless of site
                for ($RoleCount = 1; $RoleCount -le $RoleOrder.count; $RoleCount++) {
            
                    Remove-Variable -Name BuildRole -ErrorAction Ignore
                   
                    $BuildRole = $RoleOrder | Where-Object {
                        $_.order -eq $RoleCount
                    }
        
                    if ($BuildRole -is [array]) {
                        throw "Multiple Roles in the Build with order $RoleCount"
                    }
                    elseif ($null -eq $BuildRole) {
                        throw "No Roles in the Build with order $RoleCount"
                    }

                    $BuildRoleName = $BuildRole.Role

                    Remove-Variable -Name 'CurrentSiteAndConfopResources' -ErrorAction Ignore
                    foreach ($Site in $Sites) {
                        
                        $CurrentSiteAndConfopResources = @()
                        $This.Resources | foreach-Object {
                            if (($_.Network.Site -eq $Site) -and ($_.Role -eq $BuildRoleName)) {
                                $CurrentSiteAndConfopResources += $_
                            }
                    
                        }
                        if ($CurrentSiteAndConfopResources) {
                            # Multiple resources of the same Role at the same site will be ordered alphabetically by name
                            $CurrentSiteAndConfopResources = $CurrentSiteAndConfopResources | Sort-Object -Property Name
                            foreach ($CurrentSiteAndConfopResource in $CurrentSiteAndConfopResources) {
                                $ResourceCount++
                                $CurrentSiteAndConfopResource.ResourceOrder =  $ResourceCount 
                                $ResolvedResources += $CurrentSiteAndConfopResource
                            }
                        }  
                    }
                }  
            }
        }  
    }

    [Void] Save ($ResourcesFile,$Archive,$ArchiveFolder) {
        if ($Archive) {
            # Archive previous resources Plan-file and create new
            if (Test-Path -Path $ResourcesFile -ErrorAction SilentlyContinue) {
                ol v "ResourcesFile '$ResourcesFile' exists, archiving" 
                Save-DryArchiveFile -ArchiveFile $ResourcesFile -ArchiveFolder $ArchiveFolder
            }
        }
        
        ol v "Saving resourcesfile '$ResourcesFile'"
        Set-Content -Path $ResourcesFile -Value (ConvertTo-Json -InputObject $This -Depth 100) -Force
    }
}