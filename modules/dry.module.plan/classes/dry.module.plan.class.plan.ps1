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