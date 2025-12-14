using Namespace System.Collections.Generic
using Namespace System.Collections

class Resources{
    [ArrayList]$Resources

    # create an instance
    Resources ([PSCustomObject]$Configuration,[PSCustomObject]$ConfigCombo, [bool]$Interactive){
        $This.Resources = [ArrayList]::New()
        switch($Interactive){
            $false{ 
                # Loop through the resources in the build
                foreach($Resource in $Configuration.CoreConfig.resources | Where-Object{ $_.role -in @($Configuration.Build.roles.role) }){
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
            $true{
                do{
                    [System.ConsoleColor]$SelectionColor = 'DarkGreen'
                    do{
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
                        
                        $iRolesToSelectFrom = [ArrayList]::New()
                        foreach($iRole in $Configuration.build.roles){
                            $iIndex              = $iRole.order
                            $iRoleName           = $iRole.role
                            $iShort              = $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $iRoleName -Property 'role_short_name')
                            $iDescription        = $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $iRoleName -Property 'description')
                            $iRolesToSelectFrom += [PSCustomObject]@{index=$iIndex;role=$iRoleName;short=$iShort;description=$iDescription}
                        }
                        $iRolesStrings = ($($iRolesToSelectFrom | Out-String).Split("`r`n")) | Where-Object{ $_.Trim() -ne ''}
                        foreach($iString in $iRolesStrings){
                            ol i "$iString"
                        }
                        ol i " "
                        $GetDryInputParams = @{
                            Prompt             = "Enter index of a role"
                            PromptChoiceString = "$($Configuration.build.roles.order)"
                            FailedMessage      = "You need to select the index of the role, i.e. one of '$($Configuration.build.roles.order)' or 'q' to quit"
                            ValidateSet        = $Configuration.build.roles.order
                        }
                        [int]$sRoleIndex = Get-DryInput @GetDryInputParams
                        if($sRoleIndex -in $Configuration.build.roles.order){
                            $sSelected.Role  = ($iRolesToSelectFrom | Where-Object{ $_.index -eq $sRoleIndex}).role
                            $sSelected.Short = ($iRolesToSelectFrom | Where-Object{ $_.index -eq $sRoleIndex}).short
                        }
                        else{
                            break
                        }
                        $iRolesToSelectFrom = $null
                        $iRolesStrings = $null
                        [scriptblock]$ValidateShortRoleNameScript = {
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
                            FailedMessage        = "The short role name should be 2-8 chars, not contain special chars but plain letters, and not start or end with a number. The role short name is significant it you have an Active Directory that separates roles into OU's based on the role short name. If you don't, just accept the defult"
                            ValidateScript       = $ValidateShortRoleNameScript
                            ValidateScriptParams = @()
                            DefaultValue         = "$($sSelected.Short)"
                        }
                        [string]$sShortRoleName = Get-DryInput @GetDryInputParams
                        if(-not $sShortRoleName){
                            break
                        }

                        $sSelected.Short = $sShortRoleName
                        $iSubnetsToSelectFrom = [ArrayList]::New()
                        $iSubnetsIndex = 0
                        $iSubnetsIndexArray = $null; $iSubnetsIndexArray = @()
                        foreach($iSite in $Configuration.CoreConfig.network.sites){
                            foreach($iSubnet in $iSite.subnets){
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
            
                        $iSubnetsStrings = ($($iSubnetsToSelectFrom | Format-Table * | Out-String).Split("`r`n")) | Where-Object{ $_.Trim() -ne ''}
                        foreach($iString in $iSubnetsStrings){
                            ol i "$iString"
                        }
                        ol i " "
                        $GetDryInputParams = @{
                            Prompt             = "Enter index of a subnet"
                            PromptChoiceString = "$iSubnetsIndexArray"
                            FailedMessage      = "You need to select the index of the subnet, i.e. one of '$iSubnetsIndexArray'"
                            ValidateSet        = $iSubnetsIndexArray
                        }
                        [int]$sSiteIndex = Get-DryInput @GetDryInputParams
                        if($sSiteIndex){
                            [PSCustomObject]$sSite = ($iSubnetsToSelectFrom | Where-Object{ $_.index -eq $sSiteIndex}) | Select-Object -Property site,subnet_name,ip_subnet,subnet_mask,dns
                        }
                        else{
                            break
                        }
                        $sSubnetMaskBits = Convert-DryUtilsIpAddressToMaskLength -IPAddress $sSite.subnet_mask
                        $sSubnetCidrString = "$($sSite.ip_subnet)/$sSubnetMaskBits"
                        $sSelected.Site   = $sSite.site
                        $sSelected.Subnet = $sSubnetCidrString
    
                        [scriptblock]$ValidateScript = {
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
                            FailedMessage        = "You need to enter a proper ip in the correct subnet"
                            ValidateScript       = $ValidateScript
                            ValidateScriptParams = @($sSite.ip_subnet,$sSite.subnet_mask)
                        }
                        [string]$sResourceIP = Get-DryInput @GetDryInputParams
                        $sSelected.IP = $sResourceIP
                        $sSite | Add-Member -MemberType NoteProperty -Name 'ip_address' -Value $sResourceIP
                        $GetDryInputParams = @{
                            Prompt        = "Enter name of the resource"
                            FailedMessage = "The name should not be an FQDN ('.' in name is not allowed)"
                            ValidateScript ={param($DryInput); (($DryInput -ne '') -and ($null -ne $DryInput) -and ($DryInput -notmatch "\."))}
                        }
                        [string]$sResourceName = Get-DryInput @GetDryInputParams
                        if(!($sResourceName)){
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
                        if($sHappyWithSelection -in 'y','yes'){
                            $HappyWithTheSelection = $true
                        }
            
                    }
                    while ($HappyWithTheSelection -eq $false)
                    
                    if($HappyWithTheSelection){
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
                    if($AddAnotherResponse -in 'n','no'){
                        $AddAnotherResource = $false
                    }
                }
                while ($true -eq $AddAnotherResource)
            }
        }
        
        $This.DoOrder($Configuration.CoreConfig.Network,$Configuration.Build)
        $This.AddActionGuids()
    }

    [Void] AddActionGuids (){
        # Generate Action_Guids with simple sequential ordering
        $GlobalActionOrder = 0
        $This.Resources.foreach({
            foreach($Action in $_.ActionOrder){
                $GlobalActionOrder++
                # Format: simple integer order + unique GUID
                # Example: 00000001-guid, 00000002-guid, etc.
                $Action | Add-Member -MemberType NoteProperty -Name 'Action_Guid' -Value ($This.NewActionGuid($GlobalActionOrder))
            }
        })
    } 

    [string] NewActionGuid([int]$GlobalOrder){ 
        # Simplified format: 8-digit order number + GUID
        return "{0:D8}-{1}" -f $GlobalOrder, ((New-Guid).Guid)
    }


    [string] GetPreviuosDependencyActionGuid (
        [string]$Action_Guid 
    ){
        # Extract the order number from the Action_Guid (format: 00000005-guid)
        if($Action_Guid -match '^(\d+)-'){
            [int]$CurrentOrder = [int]$Matches[1]
            $PreviousOrder = $CurrentOrder - 1
            
            if($PreviousOrder -lt 1){
                throw "Unable to find previous Action - current action is first (Order: $CurrentOrder)"
            }
            
            # Find the action with the previous order by searching through resources
            foreach($Resource in $This.Resources){
                foreach($Action in $Resource.ActionOrder){
                    if($Action.Action_Guid -match "^{0:D8}-" -f $PreviousOrder){
                        return $Action.Action_Guid
                    }
                }
            }
            
            throw "Unable to find previous Action with Order $PreviousOrder"
        }
        else{
            throw "Invalid Action_Guid format: $Action_Guid"
        }
    }

    # Find first Action in plan and return true if it matches $ActionSpec
    [Bool] IsThisFirstActionInPlan ([string]$ActionGuid){
        
        # Loop though Resources using their ResourceOrder-property
        :ResourceLoop for ($ResourceOrder = 1; $ResourceOrder -le $This.Resources.Count; $ResourceOrder++){
            $CurrentResource = $This.Resources | 
            Where-Object{ 
                $_.ResourceOrder -eq $ResourceOrder
            }
            # Loop through Actions using their Order-property
            for ($ActionOrder = 1; $ActionOrder -le $CurrentResource.ActionOrder.Count; $ActionOrder++){
                $CurrentAction = $CurrentResource.ActionOrder | 
                Where-Object{ 
                    $_.Order -eq $ActionOrder
                }
                # As soon as we meet an Action without an explicit dependency, it is considered the first Action
                if($null -eq $CurrentAction.depends_on){
                    $FirstActionGuid = $CurrentAction.Action_Guid
                    Break ResourceLoop
                }
            }
        }

        if( $null -eq $FirstActionGuid ){
            throw "No first Action in Resolved Resurces found"
        }
        elseif( $FirstActionGuid -eq $ActionGuid ){
            Remove-Variable -Name FirstActionGuid -ErrorAction Ignore
            return $true
        }
        else{
            Remove-Variable -Name FirstActionGuid -ErrorAction Ignore
            return $false
        }
    }

    [Void] DoOrder ([PSObject]$Network,[PSObject]$Build){
        [array]$Sites = @(($Network.Sites).Name)
        [array]$RoleOrder  = @($Build.roles)
        $ResourceCount     = 0
        $ResolvedResources = @()

        # Resources are deployed according to the resource order in the build 
        for ($RoleCount = 1; $RoleCount -le $RoleOrder.count; $RoleCount++){
    
            Remove-Variable -Name BuildRole -ErrorAction Ignore
            
            $BuildRole = $RoleOrder | Where-Object{
                $_.order -eq $RoleCount
            }

            if($BuildRole -is [array]){
                throw "Multiple Roles in the Build with order $RoleCount"
            }
            elseif($null -eq $BuildRole){
                throw "No Roles in the Build with order $RoleCount"
            }

            $BuildRoleName = $BuildRole.Role

            Remove-Variable -Name 'CurrentSiteAndConfopResources' -ErrorAction Ignore
            foreach($Site in $Sites){
                
                $CurrentSiteAndConfopResources = @()
                $This.Resources | foreach-Object{
                    if(($_.Network.Site -eq $Site) -and ($_.Role -eq $BuildRoleName)){
                        $CurrentSiteAndConfopResources += $_
                    }
            
                }
                if($CurrentSiteAndConfopResources){
                    # Multiple resources of the same Role will be ordered alphabetically by name
                    $CurrentSiteAndConfopResources = $CurrentSiteAndConfopResources | Sort-Object -Property Name
                    foreach($CurrentSiteAndConfopResource in $CurrentSiteAndConfopResources){
                        $ResourceCount++
                        $CurrentSiteAndConfopResource.ResourceOrder =  $ResourceCount 
                        $ResolvedResources += $CurrentSiteAndConfopResource
                    }
                }  
            }
        }
    }

    [Void] Save ($ResourcesFile,$Archive,$ArchiveFolder){
        if($Archive){
            # Archive previous resources Plan-file and create new
            if(Test-Path -Path $ResourcesFile -ErrorAction SilentlyContinue){
                ol v "ResourcesFile '$ResourcesFile' exists, archiving" 
                Save-DryArchiveFile -ArchiveFile $ResourcesFile -ArchiveFolder $ArchiveFolder
            }
        }
        
        ol v "Saving resourcesfile '$ResourcesFile'"
        Set-Content -Path $ResourcesFile -Value (ConvertTo-Json -InputObject $This -Depth 100) -Force
    }
}