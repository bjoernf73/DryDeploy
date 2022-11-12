using Namespace System.Collections.Generic
using Namespace System.Collections

class InteractiveResources {
    [ArrayList] $InteractiveResources

    # create an instance
    InteractiveResources ([PSCustomObject] $Configuration,[PSCustomObject] $ConfigCombo) {

        <#
        Build                 : @{order_type=role; roles=System.Object[]}
        CoreConfig            : @{connections=System.Object[]; network=; resources=System.Object[]}
        ModuleConfigDirectory : C:\GITs\DRY\ModuleConfigs\DomainRoot\
        BaseConfigDirectory     : C:\GITs\DRYCORE\EnvConfigs\utv.local\BaseConfig
        RoleMetaConfigs       : {@{rolename=ADM; role=adm-winclient; base_config=Windows-10; description=Administration Client}, @{rolename=CA; role=ca-certauth-iss; base_config=WindowsServer; description=Windows Server Issuing Root CA}, @{rolename=CA; role=ca-certauth-root;
                                base_config=WindowsServer; description=Windows Server Standalone Root CA}, @{rolename=DC; role=dc-domctrl-add; base_config=WindowsServer; description=Additional DC}...}
        UserConfig            : @{ad.import=; CoreConfig=; credentials=System.Object[]; BaseConfigDirectory=; platforms=System.Object[]; UserConfig=; common_variables=System.Object[]; resource_variables=System.Object[]}
        credentials           : {@{alias=alternate-domain-admin; username=###DomainNB###\bjoernf}, @{alias=domain-admin; username=###DomainNB###\Administrator}}
        CredentialsType       : encryptedstring
        #>
        
        $This.InteractiveResources = [ArrayList]::New()
        
        # Create a loop that interactively builds each resource
        # Write-Host ($Configuration.Build.roles | Select-Object -Property order,role,description | Out-String)
        $iRolesRToSelectFrom = [ArrayList]::New()
        foreach ($iRole in $Configuration.Build.roles) {
            $iIndex = $iRole.order
            $iRoleName = $iRole.role
            $iDescription = $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $iRoleName -Property 'description')
            $iRolesRToSelectFrom+=[PSCustomObject]@{index=$iIndex;role=$iRoleName;description=$iDescription}
        }
        #ol i "er no feil her..."
        foreach ($iString in $($($iRolesRToSelectFrom | Out-String) -split "`n")) {
            ol i "$iString"
        }
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
            #! Previously, this called Replace-Patterns etc
            $This.Resources += $Resource
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

    [String] NewActionGuid([int]$ResourceOrder,[int]$ActionOrder) { 
        return [string]('{0:d4}' -f $ResourceOrder) + [string]('{0:d4}' -f $ActionOrder) + '0000-' + ((New-Guid).Guid)
    }


    [String] GetPreviuosDependencyActionGuid (
        [String]$Action_Guid 
    ) {
        [Int]$ResourceOrder = $Action_Guid.Substring(0,4)
        [Int]$ActionOrder = $Action_Guid.Substring(4,4)
        $ActionOrder--
        $Resource = $This.Resources | Where-Object { 
            $_.ResourceOrder -eq $ResourceOrder
        }
        $Action = $Resource.ActionOrder | Where-Object {
            $_.Order -eq $ActionOrder
        }

        if ($Null -eq $Action) {
            throw "Unable to find previous Action (Resource: $ResourceOrder, Action $ActionOrder)"
        }

        # Only return the GUID-part - that will be matched to the previous Action
        # when that Action eventually get's into to Plan
        return ($Action.Action_Guid).SubString(12)
    }

    # Find first Action in plan and return true if it matches $ActionSpec
    [Bool] IsThisFirstActionInPlan ([String] $ActionGuid) {
        
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
                if ($Null -eq $CurrentAction.depends_on) {
                    $FirstActionGuid = $CurrentAction.Action_Guid
                    Break ResourceLoop
                }
            }
        }

        if ( $Null -eq $FirstActionGuid ) {
            throw "No first Action in Resolved Resurces found"
        }
        elseif ( $FirstActionGuid -eq $ActionGuid ) {
            Remove-Variable -Name FirstActionGuid -ErrorAction Ignore
            return $True
        }
        else {
            Remove-Variable -Name FirstActionGuid -ErrorAction Ignore
            return $False
        }
    }

    [Void] DoOrder ([PSObject] $Network,[PSObject]$Build) {
        
        [Array]$Sites = @(($Network.Sites).Name)
        [Array]$RoleOrder  = @($Build.roles)
        [String]$OrderType = $Build.order_type

        if ($OrderType -notin @('site','role')) {
            [String]$OrderType = 'role'
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
            
                        if ($BuildRole -is [Array]) {
                            throw "Multiple Roles in the Build with order $RoleCount"
                        }
                        elseIf ($Null -eq $BuildRole) {
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
        
                    if ($BuildRole -is [Array]) {
                        throw "Multiple Roles in the Build with order $RoleCount"
                    }
                    elseIf ($Null -eq $BuildRole) {
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