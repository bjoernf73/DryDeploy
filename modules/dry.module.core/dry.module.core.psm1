using Namespace System.Collections.Generic
using Namespace System.Collections
<# 
 This module provides core functionality for DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.core/main/LICENSE
 
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
class Action {
    [Int]                            $ApplyOrder
    [Int]                            $PlanOrder
    [Int]                            $ActionOrder
    [String]                         $Action
    [Int]                            $Phase
    [String]                         $Description
    [String]                         $Role 
    [Guid]                           $Resource_Guid 
    [String]                         $Action_Guid
    [String]                         $ResourceName 
    [String]                         $Status
    [String]                         $Dependency_Guid
    [String]                         $Chained_Guid
    [String[]]                       $Dependency_Guids
    [Bool]                           $PlanSelected
    [Bool]                           $ApplySelected
    [Bool]                           $ResolvedActionOrder
    [PSCustomObject]                 $Credentials
    [PSCustomObject]                 $Depends_On


    # Create Action
    Action (
        [PSCustomObject]             $ActionObject,
        [Resource]                   $Resource,
        [Resources]                  $Resources,
        [Plan]                       $Plan
    ) {
        $This.ResolvedActionOrder  = $False
        $This.Action               = $ActionObject.Action
        $This.Description          = $ActionObject.Description
        $This.Role                 = $Resource.Role
        $This.ApplyOrder           = $Null
        $This.PlanOrder            = $Null
        $This.Resource_Guid        = $Resource.Resource_Guid 
        $This.Action_Guid          = $ActionObject.Action_Guid 
        $This.ResourceName         = $Resource.Name
        $This.Status               = 'Todo'
        $This.PlanSelected         = $False
        $This.ApplySelected        = $False
        if ($ActionObject.Credentials) {
            $This.Credentials      = $ActionObject.Credentials
        }

        if ($ActionObject.Phase) {
            $This.Phase            = $ActionObject.Phase
        }
        else {
            $This.Phase            = $Null
        }

        # Test if the Action is the first in Plan
        if ($Resources.IsThisFirstActionInPlan($This.Action_Guid)) {
            <#
                The first Action may resolve ActionOrder immediately. That will serve
                as a starting point for all other Actions to resolve their ActionOrder. 
                These Actions all need a Dependendy_Guid to resolve ActionOrder
            #>
            $This.ActionOrder         = 1
            $This.ResolvedActionOrder = $True
            $Plan.OrderCount          = 2
        }
        elseif ($Null -ne $ActionObject.depends_on) {
            # The Action has an explicit dependency
            $DependencyObject = New-Object -TypeName PSObject -Property @{
                'Role'            = $ActionObject.depends_on.Role
                'Action'          = $ActionObject.depends_on.action
                'Phase'           = $ActionObject.depends_on.phase
                'Dependency_Type' = $ActionObject.depends_on.dependency_type
            }
            if ($ActionObject.depends_on.dependency_type -notin 'first','last','every','chained') {
                throw "A dependency_type must be 'first','last','every' or 'chained'"
            }
            <#
                if (-not ($Null -eq $ActionObject.depends_on.phase)) {
                    $DependencyObject | Add-Member -MemberType NoteProperty -Name 'Phase' -Value $ActionObject.depends_on.phase
                }
            #>
            
            switch ($ActionObject.depends_on.dependency_type) {
                'first' {
                    # The Action will be executed only after the first occurence of the dependency_action
                    $This.Dependency_Guid  = $Plan.GetFirstDependencyActionGuid($DependencyObject)
                    $This.Action_Guid      = $Plan.ResolveActionGuid($This.Dependency_Guid,$This.Action_Guid)
                        
                }
                'last' {
                    # The Action will be executed only after the last occurance of the dependency_action
                    $This.Dependency_Guid  = $Plan.GetLastDependencyActionGuid($DependencyObject)
                    $This.Action_Guid      = $Plan.ResolveActionGuid($This.Dependency_Guid,$This.Action_Guid)
                }
                'every' {
                    # The action will be executed after every occurance of the dependency_action
                    $This.Dependency_Guids = $Plan.GetEveryDependencyActionGuid($DependencyObject)
                }
                'chained' {
                    # The action will be executed after every occurance of the previous_action
                    $This.Chained_Guid = $Resources.GetPreviuosDependencyActionGuid($This.Action_Guid)
                }
            } 
        }
    }

    # Create Action after Dependency_Action has been resolved
    Action (
        [PSCustomObject]             $ActionObject,
        [Resource]                   $Resource,
        [Resources]                  $Resources,
        [Plan]                       $Plan,
        [String]                     $Dependency_Guid,
        [String]                     $Action_Guid
    ) {
        $This.ResolvedActionOrder  = $False
        $This.Action               = $ActionObject.Action
        $This.Description          = $ActionObject.Description
        $This.Role                 = $Resource.Role
        $This.ApplyOrder           = $Null
        $This.PlanOrder            = $Null
        $This.Resource_Guid        = $Resource.Resource_Guid
        $This.Action_Guid          = $Action_Guid
        $This.ResourceName         = $Resource.Name
        $This.Status               = 'Todo'
        $This.PlanSelected         = $False
        $This.ApplySelected        = $False
        $This.Dependency_Guid      = $Dependency_Guid
        $This.Dependency_Guids     = $Null
        if ($ActionObject.Credentials) {
            $This.Credentials      = $ActionObject.Credentials
        }
        if ($ActionObject.Phase) {
            $This.Phase            = $ActionObject.Phase
        }
        else {
            $This.Phase            = $Null
        }

        $This.Action_Guid          = $Plan.ResolveActionGuid($This.Dependency_Guid,$This.Action_Guid)
    }

    # Create Action after Dependency Chain has been resolved
    Action (
        [PSCustomObject]             $ActionObject,
        [String]                     $ActionGuid
    ) {
        $This.ResolvedActionOrder  = $False
        $This.Action               = $ActionObject.Action
        $This.Description          = $ActionObject.Description
        $This.Role                 = $ActionObject.Role
        $This.ApplyOrder           = $Null
        $This.PlanOrder            = $Null
        $This.Resource_Guid        = $ActionObject.Resource_Guid
        $This.Action_Guid          = $ActionGuid
        $This.ResourceName         = $ActionObject.ResourceName
        $This.Status               = 'Todo'
        $This.PlanSelected         = $False
        $This.ApplySelected        = $False
        $This.Dependency_Guid      = $Null
        $This.Dependency_Guids     = $Null
        if ($ActionObject.Credentials) {
            $This.Credentials      = $ActionObject.Credentials
        }
        if ($ActionObject.Phase) {
            $This.Phase            = $ActionObject.Phase
        }
        else {
            $This.Phase            = $Null
        }
    }

    # Create Action from file
    Action (
        [PSCustomObject]             $ActionObject
    ) {
        $This.ResolvedActionOrder  = $ActionObject.ResolvedActionOrder
        $This.ApplyOrder           = $Null # <-- Re-evaluated at every run
        $This.PlanOrder            = $ActionObject.PlanOrder
        $This.ActionOrder          = $ActionObject.ActionOrder
        $This.Resource_Guid        = $ActionObject.Resource_Guid
        $This.Action_Guid          = $ActionObject.Action_Guid
        $This.ResourceName         = $ActionObject.ResourceName
        $This.Status               = $ActionObject.Status
        $This.PlanSelected         = $ActionObject.PlanSelected
        $This.ApplySelected        = $False # <-- Re-evaluated at every run
        
        # Properties from data
        $This.Action               = $ActionObject.Action
        $This.Description          = $ActionObject.Description
        $This.Role                 = $ActionObject.Role
        $This.Phase                = $ActionObject.Phase
        $This.Credentials          = $ActionObject.Credentials
        $This.Depends_On           = $ActionObject.Depends_On
        $This.Dependency_Guid      = $ActionObject.Dependency_Guid
    }
}

class Network {
    [String]         $Name
    [String]         $Switch_Name
    [String]         $Ip_Subnet 
    [String]         $Subnet_Mask
    [String]         $Default_Gateway
    [String]         $Reverse_Zone
    [Array]          $Dns
    [Array]          $Dns_Forwarders
    [PSCustomObject] $Dhcp
    [String]         $Ip_Address

    Network (
         [PSCustomObject] $NetworkRef,
         [Array]          $Sites
    ) {

        $Site = $Sites | 
        Where-Object { 
            $_.Name -eq $NetworkRef.site 
        }
        
        if ($Null -eq $Site) {
            Write-Error "No sites matched pattern '$($NetworkRef.site)'" -ErrorAction Stop
        }
        elseif ($Site -is [Array]) {
            Write-Error "Multiple sites matched pattern '$($NetworkRef.site)'" -ErrorAction Stop
        }
    
        $Subnet = $Site.Subnets | 
        Where-Object { 
            $_.Name -eq $NetworkRef.subnet_name 
        }
        
        if ($Null -eq $Subnet) {
            Write-Error "No subnets matched pattern '$($NetworkRef.subnet_name)'" -ErrorAction Stop
        }
        elseif ($Subnet -is [Array]) {
            Write-Error "Multiple subnets matched pattern '$($NetworkRef.subnet_name)'" -ErrorAction Stop
        }

        $This.Name            = $Subnet.Name
        $This.Switch_Name     = $Subnet.Switch_Name
        $This.Ip_Subnet       = $Subnet.Ip_Subnet
        $This.Subnet_Mask     = $Subnet.Subnet_Mask
        $This.Default_Gateway = $Subnet.Default_Gateway
        $This.Reverse_Zone    = $Subnet.Reverse_Zone
        $This.Dns             = $Subnet.Dns
        $This.Dhcp            = $Subnet.Dhcp

        if ($NetworkRef.ip_index) {
            $Snet = $Subnet.ip_subnet + '/' + $Subnet.subnet_mask
            $This.ip_address = ((Invoke-PSipcalc -NetworkAddress $Snet -Enumerate).IPenumerated)[($($NetworkRef.ip_index)-1)]
        } 
        elseif ($NetworkRef.ip_address) {
            $This.ip_address = $NetworkRef.ip_address
        }
        else {
            ol w "The Resource $($This.Name) does not have an IP address"
        }

        if ($Subnet.dns_forwarders) {
            $This.Dns_Forwarders = $Subnet.dns_forwarders
        }
    }
}

class Plan {
    [ArrayList]                       $Actions
    [Bool]                            $UnresolvedActions
    [ArrayList]                       $UnresolvedActionsList
    [Int]                             $OrderCount
    [Int]                             $ActiveActions
    
    # New Plan Object
    Plan (
        [Resources]                   $Resources
    ) {
        $This.Actions               = [ArrayList]::New()
        $This.UnresolvedActionsList = [ArrayList]::New()
        $This.OrderCount            = 1
        $This.ActiveActions         = 0
        
        # Loop backwards through the Resources
        for (
            $ResourceOrderCount = $($Resources.Resources).Count; 
            $ResourceOrderCount -gt 0; 
            $ResourceOrderCount-- 
        ) {
            # Get the resource with ResourceOrder = $ResourceCount
            [Resource] $CurrentResource = $Resources.Resources | 
            Where-Object {
                $_.ResourceOrder -eq $ResourceOrderCount
            }

            # Loop backwards through the Actions
            for (
                    $ActionOrderCount = ($CurrentResource.ActionOrder).Count; 
                    $ActionOrderCount -gt 0;
                    $ActionOrderCount--
                ) {
                [PSCustomObject] $CurrentAction = $CurrentResource.ActionOrder | 
                Where-Object {
                    $_.order -eq $ActionOrderCount
                }

                if ($Null -eq $CurrentAction) {
                    throw "Unable to find action order $ActionOrderCount on resource $($CurrentResource.Name)"
                }

                $ResolveUnresolvedActions = $False

                # Create the action object
                $Action = [Action]::New(
                    $CurrentAction,
                    $CurrentResource,
                    $Resources,
                    $This
                )

                # The Dependency_Guids property is populated only if the Action depends on 
                # multiple other Actions because of an explicit dependency. If that is the
                # case, create an independent Action for for each dependency 
                if ($Action.Dependency_Guids) {
                    foreach ($Dependency_Guid in $Action.Dependency_Guids) {
                        $Action = [Action]::New(
                            $CurrentAction,
                            $CurrentResource,
                            $Resources,
                            $This,
                            $Dependency_Guid,
                            $CurrentAction.Action_Guid
                        )
                        $This.Actions += $Action
                    }
                    # Since one or more Action were added to the Plan, Chained actions
                    # in the UnresolvedActionsList may now resolve
                    $ResolveUnresolvedActions = $True
                }
                elseif ($Action.Chained_Guid) {
                    $This.UnresolvedActionsList += $Action
                }
                else {
                    $This.Actions += $Action
                    # Since an Action was added to the Plan, Chained actions
                    # in the UnresolvedActionsList may now resolve
                    $ResolveUnresolvedActions = $True
                }

                if (
                    ($ResolveUnresolvedActions -eq $True) -And 
                    ($This.UnresolvedActionsList.Count -gt 0)
                ) {
                    $This.ResolveUnresolvedActions()
                }
            }
        }
        # $This.ResolveActions()
        $This.AddActionOrder()
    }

    # Recreate Plan from file
    Plan (
        [String] $PlanFile
    ) {
        $This.Actions               = [ArrayList]::New()
        $This.UnresolvedActionsList = [ArrayList]::New()
        $This.ActiveActions         = 0
        
        if (-not (Test-Path -Path $PlanFile -ErrorAction Ignore)) {
            throw "PlanFile not found: $PlanFile"
        }

        [PSCustomObject]$PlanObject = Get-Content -Path $PlanFile -Raw -ErrorAction Stop | 
        ConvertFrom-Json -ErrorAction Stop
    
        $This.OrderCount            = $PlanObject.OrderCount

        $PlanObject.Actions.foreach({
            $This.Actions += [Action]::New($_)
        })
    }

    [Void] hidden ResolveUnresolvedActions() {
        try {
            [ArrayList]$This.UnresolvedActionsList = @($This.UnresolvedActionsList | Sort-Object -Property Action_Guid)

            # Get each Action in Plan that the Unresolved (chained) Action depends on
            $This.UnresolvedActionsList.foreach({
                $DependencyGuid       = $_.Chained_Guid
                $ActionGuid           = $_.Action_Guid
                $DependentActionGuids = $This.GetEveryDependencyActionGuid($_.Chained_Guid)

                if ($DependentActionGuids.Count -eq 0) {
                    throw "Unable to find Dependent Action with Guid matching $DependencyGuid"
                }
                foreach ($DependentActionGuid in $DependentActionGuids) {
                    # get the ned action guid
                    $InstanceActionGuid = $This.ResolveActionGuid($DependentActionGuid,$ActionGuid) 
                    $This.Actions += [Action]::New($_,$InstanceActionGuid)
                }
            })

            # Clear the list
            $This.UnresolvedActionsList = [ArrayList]::New()
        }
        catch {
            throw $_
        }
    }

    [Void] hidden AddActionOrder() {
        $This.Actions = $This.Actions | Sort-Object -Property Action_Guid
        
        $ActionCount = 0
        $This.Actions.foreach({
            $ActionCount++
            $_.ActionOrder = $ActionCount
        })
        $This.UnresolvedActions = $False
    }

    [Void] ResolvePlanOrder($PlanFile) {
        if ($This.UnresolvedActions) {
            throw "There are unresolved actions - planorder cannot be determined"
        }
        elseif ($This.Actions.Count -lt 1) {
            throw "There are no actions to order"
        }
        else {
            $PlanOrderCount = 0
            for ($ActionOrder = 1; $ActionOrder -le $This.Actions.Count; $ActionOrder++) {
                $CurrentAction = $Null
                $CurrentAction = $This.Actions | 
                Where-Object {
                    $_.ActionOrder -eq $ActionOrder
                }
                if ($Null -eq $CurrentAction) {
                    throw "Unable to find action with ActionOrder $ActionOrder"
                }

                if ($CurrentAction.PlanSelected) {
                    $PlanOrderCount++
                    $CurrentAction.PlanOrder = $PlanOrderCount
                }
            }
        }

        # Save the plan
        $This.SaveToFile($PlanFile,$False)
    }

    [Void] ResolveApplyOrder($PlanFile) {
        if ($This.UnresolvedActions) {
            throw "There are unresolved actions - applyorder cannot be determined"
        }
        elseif ($This.Actions.Count -lt 1) {
            throw "There are no actions to order"
        }
        else {
            $ApplyOrderCount = 0
            for ($ActionOrder = 1; $ActionOrder -le $This.Actions.Count; $ActionOrder++) {
                $CurrentAction = $Null
                $CurrentAction = $This.Actions | 
                Where-Object {
                    $_.ActionOrder -eq $ActionOrder
                }
                if ($Null -eq $CurrentAction) {
                    throw "Unable to find action with ActionOrder $ActionOrder"
                }

                if ($CurrentAction.PlanSelected -and $CurrentAction.ApplySelected) {
                    $ApplyOrderCount++
                    $CurrentAction.ApplyOrder = $ApplyOrderCount
                }
            }
        }

        # Save the plan
        $This.SaveToFile($PlanFile,$False)
    }

    [Void] SaveToFile($PlanFile,$Archive) {
        if ($Archive) {
            # Archive previous plan's Plan-file and create new
            if (Test-Path -Path $PlanFile -ErrorAction SilentlyContinue) {
                ol v "Plan '$PlanFile' exists, archiving" 
                Save-DryArchiveFile -ArchiveFile $PlanFile -ArchiveSubFolder 'ArchivedPlans'
            }
        }
        
        ol v "Saving planfile '$PlanFile'"
        Set-Content -Path $PlanFile -Value (ConvertTo-Json -InputObject $This -Depth 50) -Force
    }

    [String[]] GetEveryDependencyActionGuid (
        [PSObject] $DependencySpec
    ) {
        Remove-Variable -Name EveryDependencyActionGuid -ErrorAction Ignore
        $EveryDependencyActionGuid = @()
        $This.Actions.foreach({
            if ($Null -eq $DependencySpec.Phase) {
                $DependencySpecPhase = 0
            }
            else {
                $DependencySpecPhase = $DependencySpec.Phase
            }
            
            if (
                ($_.Role -eq $DependencySpec.Role) -And 
                ($_.Action               -eq $DependencySpec.Action) -And
                ($_.Phase                -eq $DependencySpecPhase)
            ) {
                $EveryDependencyActionGuid += $_.Action_Guid
            }
        })
        return $EveryDependencyActionGuid
    }

    [String[]] GetEveryDependencyActionGuid (
        [String] $DependencyGuid
    ) {
        Remove-Variable -Name EveryDependencyActionGuid -ErrorAction Ignore
        $EveryDependencyActionGuid = @()
        $This.Actions.foreach({
            if ($_.Action_Guid -match "$DependencyGuid$") {
                $EveryDependencyActionGuid += $_.Action_Guid
            }
        })
        return $EveryDependencyActionGuid
    }


    [String] GetFirstDependencyActionGuid (
        [PSObject] $DependencySpec
    ) {
        Remove-Variable -Name EveryDependencyActionGuid -ErrorAction Ignore
        $EveryDependencyActionGuid = $This.GetEveryDependencyActionGuid($DependencySpec)
        
        if ($EveryDependencyActionGuid.Count -eq 0) {
            throw "Unable to find the Dependency Action Guid"
        }
        $EveryDependencyActionGuid = $EveryDependencyActionGuid | Sort-Object -ErrorAction Stop
        return $EveryDependencyActionGuid[0]
    }


    [String] GetLastDependencyActionGuid (
        [PSObject] $DependencySpec
    ) {
        Remove-Variable -Name EveryDependencyActionGuid -ErrorAction Ignore
        $EveryDependencyActionGuid = $This.GetEveryDependencyActionGuid($DependencySpec)
        
        if ($EveryDependencyActionGuid.Count -eq 0) {
            throw "Unable to find the Dependency Action Guid"
        }
        $EveryDependencyActionGuid = $EveryDependencyActionGuid | Sort-Object -Descending -ErrorAction Stop
        return $EveryDependencyActionGuid[0]
    }

    
    [String] ResolveActionGuid($DependencyGuid,$ActionGuid) {
        try {
            $DependencyAction     = $Null
            $DependecyActionCount = 0
            
            # Resolves the actual guid-part with a dash in front  
            $DashActualGuidPart = $ActionGuid.SubString(12)

            # Get the DependencyAction
            $This.Actions.foreach({
                if ($DependencyGuid -eq $_.Action_Guid) {
                    $DependencyAction = $_
                    $DependecyActionCount++
                }
            })

            if ($Null -eq $DependencyAction) {
                throw "Unable to find Dependency Action"
            }

            if ($DependecyActionCount -ne 1) {
                throw "Multiple Dependency Actions found"
            }

            $DependencyActionOrderPart = ($DependencyAction.Action_Guid).SubString(0,12)
            $AvailableActionOrderPart = $This.GetAvailableActionGuid($DependencyActionOrderPart)

            $AvailableGuid = $AvailableActionOrderPart + $DashActualGuidPart
            return $AvailableGuid
        }
        catch {
            throw $_
        }
    }

    [String] GetAvailableActionGuid($OrderPart) {
        try {
            $ActionOrderPart = ''
            # The OrderPart is a string like 000200050000. We must keep the 00020005 and increase the 0000-part
            # one by one and test all actions one by one to see if that order-part is available or in use
            $DependentActionOrderPart = $OrderPart.SubString(0,8)
            
            :ActionLoop for ($Count = 1; $Count -lt 9999; $Count++) {
                $ActionGuidMatch = $DependentActionOrderPart + ('{0:d4}' -f $Count)
                $MatchFound = $False
                $This.Actions.foreach({
                    if ($_.Action_Guid -Match "^$ActionGuidMatch") {
                        $MatchFound = $True
                    }
                })
                if ($MatchFound -eq $False) {
                    $ActionOrderPart = $ActionGuidMatch
                    Break ActionLoop
                }
            }
            return $ActionOrderPart
        }
        catch {
            throw $_
        }
    }
}

class PlanFilter {
    [String[]]  $ResourceNames
    [String[]]  $ExcludeResourceNames
    [String[]]  $ActionNames
    [String[]]  $ExcludeActionNames
    [Int[]]     $Phases
    [Int[]]     $ExcludePhases
    [Int[]]     $BuildSteps
    [Int[]]     $ExcludeBuildSteps

    PlanFilter (
        [String[]] $ResourceNames,
        [String[]] $ExcludeResourceNames,
        [String[]] $ActionNames,
        [String[]] $ExcludeActionNames,
        [Int[]]    $Phases,
        [Int[]]    $ExcludePhases,
        [Int[]]    $BuildSteps,
        [Int[]]    $ExcludeBuildSteps
    ) {
        $This.ResourceNames        = $ResourceNames
        $This.ExcludeResourceNames = $ExcludeResourceNames
        $This.ActionNames          = $ActionNames
        $This.ExcludeActionNames   = $ExcludeActionNames
        $This.Phases               = $Phases
        $This.ExcludePhases        = $ExcludePhases
        $This.BuildSteps         = $BuildSteps
        $This.ExcludeBuildSteps  = $ExcludeBuildSteps
    }

    [Bool] Hidden InFilter(
        [String] $ResourceName,
        [String] $ActionName,
        [Int]    $Phase,
        [Int]    $ActionOrder
    ) {
        $ResourceValidated = $ActionValidated = $PhaseValidated = $ActionOrderValidated = $False
        
        # ResourceName
        if ($Null -eq $This.ResourceNames) {
            $ResourceValidated = $True
        }
        elseif ($ResourceName -in $This.ResourceNames) {
            $ResourceValidated = $True
        }
        elseif (Test-DryCollection -Collection $This.ResourceNames -Name $ResourceName) {
            $ResourceValidated = $True 
        }

        # ExcludeResourceName
        if ($Null -eq $This.ExcludeResourceNames) {
            # do noting
        }
        elseif ($ResourceName -in $This.ExcludeResourceNames) {
            $ResourceValidated = $False
        }
        elseif (Test-DryCollection -Collection $This.ExcludeResourceNames -Name $ResourceName) {
            $ResourceValidated = $False
        }
        
        # ActionName
        if ($Null -eq $This.ActionNames) {
            $ActionValidated = $True
        }
        elseif ($ActionName -in $This.ActionNames) {
            $ActionValidated = $True
        }
        elseif (Test-DryCollection -Collection $This.ActionNames -Name $ActionName) {
            $ActionValidated = $True 
        }

        # ExcludeActionName
        if ($Null -eq $This.ExcludeActionNames) {
            # Do nothing
        }
        elseif ($ActionName -in $This.ExcludeActionNames) {
            $ActionValidated = $False
        }
        elseif (Test-DryCollection -Collection $This.ExcludeActionNames -Name $ActionName) {
            $ActionValidated = $False 
        }

        # Phase
        if ($Null -eq $This.Phases) {
            $PhaseValidated = $True
        }
        elseif ($Phase -in $This.Phases) {
            $PhaseValidated = $True
        }

        # ExcludePhase
        if ($Null -eq $This.ExcludePhases) {
            # do noting
        }
        elseif ($Phase -in $This.ExcludePhases) {
            $PhaseValidated = $False
        }

        # ActionOrder
        if ($Null -eq $This.BuildSteps) {
            $ActionOrderValidated = $True
        }
        elseif ($ActionOrder -in $This.BuildSteps) {
            $ActionOrderValidated = $True
        }

        # ExcludeActionOrder
        if ($Null -eq $This.ExcludeBuildSteps) {
            # do noting
        }
        elseif ($ActionOrder -in $This.ExcludeBuildSteps) {
            $ActionOrderValidated = $False
        }

        # return true only if all are validated, false if not
        if (
            $ResourceValidated -and 
            $ActionValidated   -and 
            $PhaseValidated    -and
            $ActionOrderValidated
        ) {
            return $True
        }
        else {
            return $False
        }
    }
}

class Resource {
    [String]          $Name 
    [String]          $RoleName
    [String]          $Role # Changed back
    [String]          $OS_Tag
    [String]          $Description
    [Int]             $ResourceOrder
    [String]          $OSConfigPath
    [String]          $RolePath
    [String]          $ConfigurationTargetPath
    [Guid]            $Resource_Guid # Changed back
    [PSCustomObject]  $Network
    [Network]         $Resolved_Network # Changed back
    [PSCustomObject]  $ActionOrder
    [PSCustomObject]  $Options

    # Initial creation of the resource
    Resource (
        [String]          $Name,
        [String]          $RoleName,
        [String]          $Role,
        [String]          $OS_Tag,
        [String]          $OSConfigPath,
        [String]          $Description,
        [PSCustomObject]  $Network,
        [PSCustomObject]  $Options
    ) {
        $This.Name                     = $Name
        $This.RoleName                 = $RoleName
        $This.Role                     = $Role
        $This.OS_Tag                   = $OS_Tag
        $This.OSConfigPath             = Join-Path -Path $OSConfigPath -ChildPath $OS_Tag -Resolve
        $This.Description              = $Description
        $This.ResourceOrder            = 0
        $This.Network                  = $Network
        $This.Resolved_Network         = [Network]::New($Network,$($GLOBAL:dry_var_global_Configuration).network.sites)
        $This.RolePath                 = Join-Path -Path $GLOBAL:dry_var_global_ConfigCombo.moduleconfig.rolespath -ChildPath $Role -Resolve
        $This.ConfigurationTargetPath  = Join-Path -Path ($GLOBAL:dry_var_global_RootWorkingDirectory + '\TempConfigs') -ChildPath $This.Name
        $This.Resource_Guid            = $($(New-Guid).Guid)
        $This.Options                  = $Options

        Remove-Variable -Name BuildTemplate -ErrorAction Ignore
        $BuildTemplate = $($GLOBAL:dry_var_global_Configuration).build.role_order | Where-Object {
            $_.role -eq $Role
        }

        if ($Null -eq $BuildTemplate) {
            ol w "The Build does not contain a Role '$($This.Role)'"
            throw "The Build does not contain a Role '$($This.Role)'"
        }
        elseif ($BuildTemplate -is [Array]) {
            ol w "The Build contains multiple Roles matching '$($This.Role)'"
            throw "The Build contains multiple Roles matching '$($This.Role)'"
        }
        # Get a copy of the Build Object. The Build is now instantiated by a Resource, 
        # but there may be many Resources in the Plan using that Tempolate. So, not to contaminate 
        # the Template with the unique GUID of each Action, use a copy
        $ResourceBuild = Get-DryPSObjectCopy -Object $BuildTemplate
        $ResourceBuild.action_order.foreach({
            $_ | Add-Member -MemberType NoteProperty -Name 'Role' -Value $Role
        })

        $This.ActionOrder = $ResourceBuild.action_order
    }
}

class Resources {
    [ArrayList] $Resources

    # create an instance
    Resources (
        [PSCustomObject] $Configuration,
        [List[PSObject]] $CommonVariables
    ) {
        
        $This.Resources = [ArrayList]::New()
        # Loop through the resources in the build
        foreach ($Resource in $Configuration.resources | Where-Object { $_.role -in @($Configuration.build.role_order.role) }) {
            $Resource = [Resource]::New(
                $Resource.Name,
                $(Get-DryRoleMetaConfigProperty -Configuration $Configuration -Role $Resource.Role -Property 'rolename'),
                $Resource.Role,
                $(Get-DryRoleMetaConfigProperty -Configuration $Configuration -Role $Resource.Role -Property 'os_tag'),
                $Configuration.OSConfigDirectory,
                $(Get-DryRoleMetaConfigProperty -Configuration $Configuration -Role $Resource.Role -Property 'description'),
                $Resource.Network,
                $Resource.Options
            )

            # Add Resource-specific variables to $CommonVariables --> $ResourceVariables
            $ResolveDryVariablesParams = @{
                Variables     = $Configuration.resource_variables 
                Configuration = $Configuration 
                VariablesList = $CommonVariables
                Resource      = $Resource
                OutputType    = 'list'
            }
            Remove-Variable -Name ResourceVariables -ErrorAction Ignore
            $ResourceVariables  = Resolve-DryVariables @ResolveDryVariablesParams

            $Resource           = Resolve-DryReplacementPatterns -InputObject $Resource -Variables $ResourceVariables
            $This.Resources    += $Resource
            Remove-Variable -Name 'ResourceVariables','ResolveDryVariablesParams' -ErrorAction Ignore
        }

        $This.DoOrder()
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
    [Bool] IsThisFirstActionInPlan (
        [String] $ActionGuid
    ) {
        
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

    [Void] DoOrder (
    ) {
        
        $Sites = ($GLOBAL:dry_var_global_Configuration.Network.Sites).Name
        
        # loop thorugh the deployment Build
        $Build = $GLOBAL:dry_var_global_Configuration.build
        [Array]$RoleOrder  = $Build.role_order 
        [String]$OrderType = $Build.order_type

        if ($OrderType -notin @('site','role')) {
            throw "The Deployment Builds' 'order_type' property must be 'site' or 'role'"
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

    [Void] SaveToFile($ResourcesFile,$Archive) {
        if ($Archive) {
            # Archive previous resources Plan-file and create new
            if (Test-Path -Path $ResourcesFile -ErrorAction SilentlyContinue) {
                ol v "ResourcesFile '$ResourcesFile' exists, archiving" 
                Save-DryArchiveFile -ArchiveFile $ResourcesFile -ArchiveSubFolder 'ArchivedResources'
            }
        }
        
        ol v "Saving resourcesfile '$ResourcesFile'"
        Set-Content -Path $ResourcesFile -Value (ConvertTo-Json -InputObject $This -Depth 100) -Force
    }
}

$ScriptBlocksPath      = "$PSScriptRoot\scriptblocks\*.ps1"
$ScriptBlocks          = Resolve-Path -Path $ScriptBlocksPath -ErrorAction Stop
ForEach ($ScriptBlock in $ScriptBlocks) {
    . $ScriptBlock.Path
}

$ExportedFunctionsPath = "$PSScriptRoot\xfunctions\*.ps1"
$Functions = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach ($Function in $Functions) {
    . $Function.Path
}