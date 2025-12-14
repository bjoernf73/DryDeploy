using Namespace System.Collections.Generic
using Namespace System.Collections
class DryAction{
    [int]$ApplyOrder
    [int]$PlanOrder
    [int]$ActionOrder
    [string]$Action
    [int]$Phase
    [string]$Source
    [string]$Description
    [string]$Role 
    [Guid]$Resource_Guid 
    [string]$Action_Guid
    [string]$ResourceName
    [PSCustomObject]$Resource
    [string]$Status
    [string]$Dependency_Guid
    [string]$Chained_Guid
    [String[]]$Dependency_Guids
    [Bool]$PlanSelected
    [Bool]$ApplySelected
    [Bool]$ResolvedActionOrder
    [PSCustomObject]$Credentials
    [PSCustomObject]$Depends_On

    DryAction (
        [PSCustomObject]$ActionObject,
        [Resource]$Resource,
        [Resources]$Resources,
        [Plan]$Plan)
    {
        $This.ResolvedActionOrder  = $false
        $This.Action               = $ActionObject.Action
        $This.Description          = $ActionObject.Description
        $This.Role                 = $Resource.Role
        $This.ApplyOrder           = $null
        $This.PlanOrder            = $null
        $This.Resource_Guid        = $Resource.Resource_Guid 
        $This.Action_Guid          = $ActionObject.Action_Guid 
        $This.ResourceName         = $Resource.Name
        $This.Resource             = $Resource 
        $This.Status               = 'Todo'
        $This.PlanSelected         = $false
        $This.ApplySelected        = $false
        if($ActionObject.Credentials){
            $This.Credentials      = $ActionObject.Credentials
        }

        if($ActionObject.Phase){
            $This.Phase            = $ActionObject.Phase
        }
        else{
            $This.Phase            = $null
        }

        # The Action may get it's files from the role repository or a base repository
        if($ActionObject.Source){
            if($ActionObject.Source -in @('role','base')){
                $This.Source = $ActionObject.Source
            }
            else{
                throw "An Action's Source property must be 'base', 'role' or null"
            }
        }
        else{
            $This.Source = 'role'
        }

        # Test if the Action is the first in Plan
        if($Resources.IsThisFirstActionInPlan($This.Action_Guid)){
            <#
                The first Action may resolve ActionOrder immediately. That will serve
                as a starting point for all other Actions to resolve their ActionOrder. 
                These Actions all need a Dependendy_Guid to resolve ActionOrder
            #>
            $This.ActionOrder         = 1
            $This.ResolvedActionOrder = $true
            $Plan.OrderCount          = 2
        }
        elseif($null -ne $ActionObject.depends_on){
            # The Action has an explicit dependency
            if($ActionObject.depends_on.dependency_type -notin 'first','last','every','numbered','chained'){
                throw "A dependency_type must be 'first', 'last', 'every', 'numbered' or 'chained'"
            }
           
            switch($ActionObject.depends_on.dependency_type){
                'first'{
                    # The Action will be executed only after the first occurence of the dependency_action
                    $This.Dependency_Guid  = $Plan.GetFirstDependencyActionGuid($ActionObject.depends_on)
                    $This.Action_Guid      = $Plan.ResolveActionGuid($This.Dependency_Guid,$This.Action_Guid)
                        
                }
                'last'{
                    # The Action will be executed only after the last occurance of the dependency_action
                    $This.Dependency_Guid  = $Plan.GetLastDependencyActionGuid($ActionObject.depends_on)
                    $This.Action_Guid      = $Plan.ResolveActionGuid($This.Dependency_Guid,$This.Action_Guid)
                }
                'every'{
                    # The action will be executed after every occurance of the dependency_action
                    $This.Dependency_Guids = $Plan.GetEveryDependencyActionGuid($ActionObject.depends_on)
                }
                'numbered'{
                    # The action will be executed only after the n'th occurance of the dependency_action
                    $This.Dependency_Guids = $Plan.GetNumberedDependencyActionGuid($ActionObject.depends_on)
                }
                'chained'{
                    # The action will be executed after every occurance of the previous_action
                    $This.Chained_Guid = $Resources.GetPreviuosDependencyActionGuid($This.Action_Guid)
                }
            } 
        }
    }

    # Create Action after Dependency_Action has been resolved
    DryAction (
        [PSCustomObject]$ActionObject,
        [Resource]$Resource,
        [Resources]$Resources,
        [Plan]$Plan,
        [string]$Dependency_Guid,
        [string]$Action_Guid){

        $This.ResolvedActionOrder  = $false
        $This.Action               = $ActionObject.Action
        $This.Description          = $ActionObject.Description
        $This.Role                 = $Resource.Role
        $This.ApplyOrder           = $null
        $This.PlanOrder            = $null
        $This.Resource_Guid        = $Resource.Resource_Guid
        $This.Action_Guid          = $Action_Guid
        $This.ResourceName         = $Resource.Name
        $This.Resource             = $Resource
        $This.Status               = 'Todo'
        $This.PlanSelected         = $false
        $This.ApplySelected        = $false
        $This.Dependency_Guid      = $Dependency_Guid
        $This.Dependency_Guids     = $null

        if($ActionObject.Credentials){
            $This.Credentials      = $ActionObject.Credentials
        }
        if($ActionObject.Phase){
            $This.Phase            = $ActionObject.Phase
        }
        else{
            $This.Phase            = $null
        }

        # The Action may get it's files from the role repository or a base repository
        if($ActionObject.Source){
            if($ActionObject.Source -in @('role','base')){
                $This.Source = $ActionObject.Source
            }
            else{
                throw "An Action's Source property must be 'base', 'role' or null"
            }
        }
        else{
            $This.Source = 'role'
        }
        $This.Action_Guid = $Plan.ResolveActionGuid($This.Dependency_Guid,$This.Action_Guid)
    }

    # Create Action after Dependency Chain has been resolved
    DryAction (
        [PSCustomObject]$ActionObject,
        [string]$ActionGuid){
        $This.ResolvedActionOrder  = $false
        $This.Action               = $ActionObject.Action
        $This.Description          = $ActionObject.Description
        $This.Role                 = $ActionObject.Role
        $This.ApplyOrder           = $null
        $This.PlanOrder            = $null
        $This.Resource_Guid        = $ActionObject.Resource_Guid
        $This.Action_Guid          = $ActionGuid
        $This.ResourceName         = $ActionObject.ResourceName
        $This.Resource             = $ActionObject.Resource
        $This.Status               = 'Todo'
        $This.PlanSelected         = $false
        $This.ApplySelected        = $false
        $This.Dependency_Guid      = $null
        $This.Dependency_Guids     = $null
        if($ActionObject.Credentials){
            $This.Credentials      = $ActionObject.Credentials
        }
        if($ActionObject.Phase){
            $This.Phase            = $ActionObject.Phase
        }
        else{
            $This.Phase            = $null
        }
        # The Action may get it's files from the role repository or a base repository
        if($ActionObject.Source){
            if($ActionObject.Source -in @('role','base')){
                $This.Source = $ActionObject.Source
            }
            else{
                throw "An Action's Source property must be 'base', 'role' or null"
            }
        }
        else{
            $This.Source = 'role'
        }
    }

    # Create Action from file
    DryAction (
        [PSCustomObject]$ActionObject){
        $This.ResolvedActionOrder  = $ActionObject.ResolvedActionOrder
        $This.ApplyOrder           = $null # <-- Re-evaluated at every run
        $This.PlanOrder            = $ActionObject.PlanOrder
        $This.ActionOrder          = $ActionObject.ActionOrder
        $This.Resource_Guid        = $ActionObject.Resource_Guid
        $This.Action_Guid          = $ActionObject.Action_Guid
        $This.ResourceName         = $ActionObject.ResourceName
        $This.Resource             = $ActionObject.Resource
        $This.Status               = $ActionObject.Status
        $This.PlanSelected         = $ActionObject.PlanSelected
        $This.ApplySelected        = $false # <-- Re-evaluated at every run
        # Properties from data
        $This.Action               = $ActionObject.Action
        $This.Description          = $ActionObject.Description
        $This.Role                 = $ActionObject.Role
        $This.Phase                = $ActionObject.Phase
        $This.Source               = $ActionObject.Source
        $This.Credentials          = $ActionObject.Credentials
        $This.Depends_On           = $ActionObject.Depends_On
        $This.Dependency_Guid      = $ActionObject.Dependency_Guid
    }
}

class Plan{
    [ArrayList]$Actions
    [Bool]$UnresolvedActions
    [ArrayList]$UnresolvedActionsList
    [int]$OrderCount
    [int]$ActiveActions
    [DateTime]$PlannedTime  # updated any time you create or modify a plan
    [nullable[Datetime]]$EndTime      # set in DryDeploy's finally - will be reset to null any time $PlannedTime is modified
    
    # New Plan Object
    Plan ([Resources]$Resources){
        $This.Actions               = [ArrayList]::New()
        $This.UnresolvedActionsList = [ArrayList]::New()
        $This.OrderCount            = 1
        $This.ActiveActions         = 0
        $This.PlannedTime           = [DateTime](Get-Date)
        $This.EndTime               = $null
        
        # Loop backwards through the Resources
        for ($ResourceOrderCount = $($Resources.Resources).Count; $ResourceOrderCount -gt 0; $ResourceOrderCount-- ){
            # Get the resource with ResourceOrder = $ResourceCount
            [Resource]$CurrentResource = $Resources.Resources | 
            Where-Object{
                $_.ResourceOrder -eq $ResourceOrderCount
            }

            # Loop backwards through the Actions
            for ($ActionOrderCount = ($CurrentResource.ActionOrder).Count; $ActionOrderCount -gt 0; $ActionOrderCount-- ){
                [PSCustomObject]$CurrentAction = $CurrentResource.ActionOrder | 
                Where-Object{
                    $_.order -eq $ActionOrderCount
                }
                if($null -eq $CurrentAction){
                    throw "Unable to find action order $ActionOrderCount on resource $($CurrentResource.Name)"
                }

                $ResolveUnresolvedActions = $false

                # Create the action object
                $Action = [DryAction]::New(
                    $CurrentAction,
                    $CurrentResource,
                    $Resources,
                    $This
                )

                # The Dependency_Guids property is populated only if the Action depends on 
                # multiple other Actions because of an explicit dependency. If that is the
                # case, create an independent Action for for each dependency 
                if($Action.Dependency_Guids){
                    # Extract the GUID part from the original Action_Guid to reuse for all instances
                    if($CurrentAction.Action_Guid -match '^(\d+)-(.+)$'){
                        $OriginalOrderPrefix = $Matches[1]
                        $SharedGuidPart = $Matches[2]
                    }
                    else{
                        throw "Invalid Action_Guid format: $($CurrentAction.Action_Guid)"
                    }
                    
                    $InstanceCount = 0
                    foreach($Dependency_Guid in $Action.Dependency_Guids){
                        $InstanceCount++
                        
                        # All instances share the same GUID part (so chained actions can find them all)
                        # But give each a unique temporary order prefix to ensure deterministic sorting
                        # Use a very high number plus instance count to avoid collisions
                        $TempOrderPrefix = 99900000 + $InstanceCount
                        $UniqueActionGuid = "{0:D8}-{1}" -f $TempOrderPrefix, $SharedGuidPart
                        
                        $Action = [DryAction]::New(
                            $CurrentAction,
                            $CurrentResource,
                            $Resources,
                            $This,
                            $Dependency_Guid,
                            $UniqueActionGuid
                        )
                        $This.Actions.Add($Action)
                    }
                    # Since one or more Action were added to the Plan, Chained actions
                    # in the UnresolvedActionsList may now resolve
                    $ResolveUnresolvedActions = $true
                }
                elseif($Action.Chained_Guid){
                    $This.UnresolvedActionsList.Add($Action)
                }
                else{
                    $This.Actions.Add($Action)
                    # Since an Action was added to the Plan, Chained actions
                    # in the UnresolvedActionsList may now resolve
                    $ResolveUnresolvedActions = $true
                }

                if(($ResolveUnresolvedActions -eq $true) -and ($This.UnresolvedActionsList.Count -gt 0)){
                    $This.ResolveUnresolvedActions()
                }
            }
        }
        # $This.ResolveActions()
        $This.AddActionOrder()
    }

    # Recreate Plan from file
    Plan ([string]$PlanFile){
        $This.Actions               = [ArrayList]::New()
        $This.UnresolvedActionsList = [ArrayList]::New()
        $This.ActiveActions         = 0
        
        if(-not (Test-Path -Path $PlanFile -ErrorAction Ignore)){
            throw "PlanFile not found: $PlanFile"
        }

        [PSCustomObject]$PlanObject = Get-Content -Path $PlanFile -Raw -ErrorAction Stop | 
        ConvertFrom-Json -ErrorAction Stop
        $This.OrderCount = $PlanObject.OrderCount
        $PlanObject.Actions.foreach({
            $This.Actions.Add([DryAction]::New($_))
        })
        $This.PlannedTime = [DateTime]($PlanObject.PlannedTime)
        if($null -eq $PlanObject.EndTime){
            $This.EndTime = $null
        }
        else{
            $This.EndTime = [DateTime]($PlanObject.PlannedTime)
        }
    }

    [Void] hidden ResolveUnresolvedActions(){
        try{
            ol v "Resolving $($This.UnresolvedActionsList.Count) unresolved (chained) actions"
            $This.UnresolvedActionsList = @($This.UnresolvedActionsList | Sort-Object -Property Action_Guid)

            # Get each Action in Plan that the Unresolved (chained) Action depends on
            $This.UnresolvedActionsList.foreach({
                $DependencyGuid       = $_.Chained_Guid
                $ActionGuid           = $_.Action_Guid
                ol v "Resolving chained action: Role='$($_.Role)' Action='$($_.Action)' Resource='$($_.ResourceName)'"
                ol v "Dependency GUID: $DependencyGuid"
                ol v "Action GUID: $ActionGuid"
                
                # For chained actions, we need to find the previous action by GUID part
                # because the previous action may have had its Action_Guid modified by ResolveActionGuid
                $DependentActionGuids = $This.GetEveryDependencyActionGuid($_.Chained_Guid)

                if($DependentActionGuids.Count -eq 0){
                    ol e "Unable to find Dependent Action with Guid matching $DependencyGuid"
                    ol e "Available actions in plan: $($This.Actions.Count)"
                    ol e "Searching for GUID part in existing actions..."
                    # Debug: show what GUIDs are in the plan
                    $This.Actions | ForEach-Object { ol e "  Available: $($_.Action_Guid) - $($_.Role) / $($_.Action)" }
                    throw "Unable to find Dependent Action with Guid matching $DependencyGuid"
                }
                
                ol v "Found $($DependentActionGuids.Count) dependent action(s)"
                
                # For chained dependencies, create one instance after EACH occurrence
                # Extract the GUID part to reuse for all instances
                if($ActionGuid -match '^(\d+)-(.+)$'){
                    $OriginalOrderPrefix = $Matches[1]
                    $SharedGuidPart = $Matches[2]
                }
                else{
                    throw "Invalid Action_Guid format for chained action: $ActionGuid"
                }
                
                $InstanceCount = 0
                foreach($DependentActionGuid in $DependentActionGuids){
                    $InstanceCount++
                    
                    # All instances share the same GUID part (so subsequent chains can find them)
                    # Use a unique temporary order prefix to ensure deterministic sorting
                    $TempOrderPrefix = 99900000 + $InstanceCount
                    $UniqueActionGuid = "{0:D8}-{1}" -f $TempOrderPrefix, $SharedGuidPart
                    
                    # get the action guid
                    $InstanceActionGuid = $This.ResolveActionGuid($DependentActionGuid,$UniqueActionGuid) 
                    ol v "Creating chained instance $InstanceCount with GUID: $InstanceActionGuid"
                    $This.Actions.Add([DryAction]::New($_,$InstanceActionGuid))
                }
            })
            $This.UnresolvedActionsList = [ArrayList]::New()
            ol v "All unresolved actions have been resolved"
        }
        catch{
            throw $_
        }
    }

    [Void] hidden AddActionOrder(){
        ol v "Finalizing action order for $($This.Actions.Count) actions"
        
        if(($This.Actions).count -gt 1){
            # Sort by Action_Guid which now has simple integer prefix
            ol v "Sorting actions by Action_Guid"
            [ArrayList]$This.Actions = [ArrayList]($This.Actions | Sort-Object -Property Action_Guid)
        }
        
        # Assign sequential ActionOrder based on sorted position
        ol v "Assigning sequential ActionOrder and normalizing Action_Guids"
        $ActionCount = 0
        $This.Actions.foreach({
            $ActionCount++
            $_.ActionOrder = $ActionCount
            
            # Ensure Action_Guid reflects the current order
            if($_.Action_Guid -match '^\d+-(.+)$'){
                $GuidPart = $Matches[1]
                $_.Action_Guid = "{0:D8}-{1}" -f $ActionCount, $GuidPart
            }
        })
        $This.UnresolvedActions = $false
        ol v "Action ordering complete. All $ActionCount actions have sequential order."
    }

    [Void] ResolvePlanOrder($PlanFile){

        if($This.UnresolvedActions){
            throw "There are unresolved actions - planorder cannot be determined"
        }
        elseif($This.Actions.Count -lt 1){
            ol w "There are no actions in the Plan. The cause of this may be one of: "
            ol w " "
            ol w " a. The file '[EnvConfig]/CoreConfig/Resources.json' probably contains no instances of roles defined in the selected ModuleConfig. A ModuleConfig is like a menu from which the EnvConfig may select none, one or multiple instances of roles. But the ModuleConfig has only the blueprints, not the instances."
            ol w " "
            ol w " b. You ran DryDeploy in interactive mode, but never submitted any instances of roles to the plan."
            throw "There are no actions to order"
        }
        else{
            $PlanOrderCount = 0
            for ($ActionOrder = 1; $ActionOrder -le $This.Actions.Count; $ActionOrder++){
                $CurrentAction = $null
                $CurrentAction = $This.Actions | 
                Where-Object{
                    $_.ActionOrder -eq $ActionOrder
                }
                if($null -eq $CurrentAction){
                    throw "Unable to find action with ActionOrder $ActionOrder"
                }

                if($CurrentAction.PlanSelected){
                    $PlanOrderCount++
                    $CurrentAction.PlanOrder = $PlanOrderCount
                }
            }
        }
        $This.Save($PlanFile,$false,$null)
    }

    [Void] RewindPlanOrder($PlanFile){
        for ($ROrder = 1; $ROrder -le ($This.Actions | Where-Object{ $_.PlanOrder -gt 0}).Count; $ROrder++){
            $CurrentAction = $null
            $CurrentAction = $This.Actions | 
            Where-Object{
                $_.PlanOrder -eq $ROrder
            }

            if($CurrentAction.Status -eq 'Todo'){
                if($ROrder -eq 1){
                     break
                }
                else{
                    ($This.Actions | Where-Object{ $_.PlanOrder -eq ($ROrder-1)}).Status = 'Todo'
                    break
                }
            }
            elseif($ROrder -eq (($This.Actions | Where-Object{ $_.PlanOrder -gt 0}).Count)){
                ($This.Actions | Where-Object{ $_.PlanOrder -eq ($ROrder)}).Status = 'Todo'
                break
            }
        }
        $This.Save($PlanFile,$false,$null)
    }

    [Void] FastForwardPlanOrder($PlanFile){
        for ($ROrder = 1; $ROrder -le ($This.Actions | Where-Object{ $_.PlanOrder -gt 0}).Count; $ROrder++){
            $CurrentAction = $null
            $CurrentAction = $This.Actions | 
            Where-Object{
                $_.PlanOrder -eq $ROrder
            }
            if($CurrentAction.Status -eq 'Success'){
                # the last element in plan - break and no change if we've reached that
                if($ROrder -eq (($This.Actions | Where-Object{ $_.PlanOrder -gt 0}).Count)){
                     break
                }
            }
            else{
                ($This.Actions | Where-Object{ $_.PlanOrder -eq ($ROrder)}).Status = 'Success'
                break
            }
        }
        $This.Save($PlanFile,$false,$null)
    }

    [Void] ResolveApplyOrder($PlanFile){
        if($This.UnresolvedActions){
            throw "There are unresolved actions - applyorder cannot be determined"
        }
        elseif($This.Actions.Count -lt 1){
            throw "There are no actions to order"
        }
        else{
            $ApplyOrderCount = 0
            for ($ActionOrder = 1; $ActionOrder -le $This.Actions.Count; $ActionOrder++){
                $CurrentAction = $null
                $CurrentAction = $This.Actions | 
                Where-Object{
                    $_.ActionOrder -eq $ActionOrder
                }
                if($null -eq $CurrentAction){
                    throw "Unable to find action with ActionOrder $ActionOrder"
                }
                if($CurrentAction.PlanSelected -and $CurrentAction.ApplySelected){
                    $ApplyOrderCount++
                    $CurrentAction.ApplyOrder = $ApplyOrderCount
                }
            }
        }
        $This.Save($PlanFile,$false,$null)
    }

    [Void] Save ($PlanFile,$Archive,$ArchiveFolder){
        if($Archive){
            # Archive previous Plan-file and create new
            if(Test-Path -Path $PlanFile -ErrorAction SilentlyContinue){
                Save-DryArchiveFile -ArchiveFile $PlanFile -ArchiveFolder $ArchiveFolder
            }
        }
        ol v "Saving Planfile '$PlanFile'"
        Set-Content -Path $PlanFile -Value (ConvertTo-Json -InputObject $This -Depth 100) -Force
    }


    [String[]] GetEveryDependencyActionGuid (
        [PSObject]$DependencySpec){

        $EveryDependencyActionGuid = $null
        $EveryDependencyActionGuid = @()
        $This.Actions.foreach({
            if($null -eq $DependencySpec.Phase){
                $DependencySpecPhase = 0
            }
            else{
                $DependencySpecPhase = $DependencySpec.Phase
            }
            if(($_.Role   -eq $DependencySpec.Role) -And 
                ($_.Action -eq $DependencySpec.Action) -And
                ($_.Phase  -eq $DependencySpecPhase)){
                $EveryDependencyActionGuid += $_.Action_Guid
            }
        })
        return $EveryDependencyActionGuid
    }


    [String[]] GetEveryDependencyActionGuid (
        [string]$DependencyGuid){
        <#
            This overload is used for chained dependencies where we need to find
            all instances of an action across multiple resources. With the new format,
            we match by the GUID part (after the dash), not the order prefix.
        #>
        $EveryDependencyActionGuid = $null
        $EveryDependencyActionGuid = @()
        
        ol v "Searching for actions matching dependency GUID: $DependencyGuid"
        
        # Extract the GUID part from the DependencyGuid (everything after the dash)
        if($DependencyGuid -match '^(\d+)-(.+)$'){
            $GuidPart = $Matches[2]
            ol v "Extracted GUID part: $GuidPart"
            ol v "Searching $($This.Actions.Count) actions for matching GUID part"
            
            $This.Actions.foreach({
                # Match actions that have the same GUID part
                if($_.Action_Guid -match "-$([regex]::Escape($GuidPart))$"){
                    ol v "Found match: $($_.Action_Guid) (Role: $($_.Role), Action: $($_.Action))"
                    $EveryDependencyActionGuid += $_.Action_Guid
                }
            })
        }
        else{
            ol v "Using fallback matching (old format or direct GUID)"
            # Fallback for old format or direct GUID matching
            $This.Actions.foreach({
                if($_.Action_Guid -match "$DependencyGuid$"){
                    ol v "Found match: $($_.Action_Guid)"
                    $EveryDependencyActionGuid += $_.Action_Guid
                }
            })
        }
        
        ol v "Found $($EveryDependencyActionGuid.Count) total match(es)"
        return $EveryDependencyActionGuid
    }


    [string] GetFirstDependencyActionGuid (
        [PSObject]$DependencySpec){
        $EveryDependencyActionGuid = $null
        $EveryDependencyActionGuid = $This.GetEveryDependencyActionGuid($DependencySpec)
        if($EveryDependencyActionGuid.Count -eq 0){
            throw "Unable to find the Dependency Action Guid"
        }
        $EveryDependencyActionGuid = $EveryDependencyActionGuid | Sort-Object -ErrorAction Stop
        return $EveryDependencyActionGuid[0]
    }

    [string] GetLastDependencyActionGuid (
        [PSObject]$DependencySpec){
        $EveryDependencyActionGuid = $null
        $EveryDependencyActionGuid = $This.GetEveryDependencyActionGuid($DependencySpec)
        if($EveryDependencyActionGuid.Count -eq 0){
            throw "Unable to find the Dependency Action Guid"
        }
        $EveryDependencyActionGuid = $EveryDependencyActionGuid | Sort-Object -Descending -ErrorAction Stop
        return $EveryDependencyActionGuid[0]
    }

    [string] GetNumberedDependencyActionGuid ([PSObject]$DependencySpec){
        [int]$DependencyNumberedActionOrder = ($DependencySpec.dependency_numbered_action)-1
        $EveryDependencyActionGuid = $null
        $EveryDependencyActionGuid = $This.GetEveryDependencyActionGuid($DependencySpec)
        if($EveryDependencyActionGuid.Count -eq 0){
            throw "Unable to find the Dependency Action Guid"
        }
        $EveryDependencyActionGuid = $EveryDependencyActionGuid | Sort-Object -ErrorAction Stop
        if($null -eq $EveryDependencyActionGuid[$DependencyNumberedActionOrder]){
            throw "There is no numbered dependency Action nr $($DependencySpec.dependency_numbered_action)"
        }
        return $EveryDependencyActionGuid[$DependencyNumberedActionOrder]
    }
    
    [string] ResolveActionGuid($DependencyGuid,$ActionGuid){
        try{
            ol v "Resolving Action GUID after dependency"
            ol v "Dependency GUID: $DependencyGuid"
            ol v "Original Action GUID: $ActionGuid"
            
            # Find the dependency action
            $DependencyAction = $This.Actions | Where-Object { $_.Action_Guid -eq $DependencyGuid }
            
            if($null -eq $DependencyAction){
                ol e "Unable to find Dependency Action with GUID: $DependencyGuid"
                ol e "Available actions count: $($This.Actions.Count)"
                throw "Unable to find Dependency Action with GUID: $DependencyGuid"
            }
            if(@($DependencyAction).Count -ne 1){
                ol e "Multiple Dependency Actions found with GUID: $DependencyGuid (Count: $(@($DependencyAction).Count))"
                throw "Multiple Dependency Actions found with GUID: $DependencyGuid"
            }
            
            # Extract the order from the dependency's Action_Guid (not from ActionOrder property which isn't set yet)
            # During initial plan construction, ActionOrder is null/0, but the Action_Guid has the order encoded
            if($DependencyAction.Action_Guid -match '^(\d+)-'){
                $DependencyOrder = [int]$Matches[1]
            }
            else{
                throw "Unable to extract order from Dependency Action_Guid: $($DependencyAction.Action_Guid)"
            }
            
            # Find the next available position after the dependency
            # Check all existing actions to find the highest order that's greater than dependency
            $InsertAfterOrder = $DependencyOrder
            
            # Get all actions that depend on this SPECIFIC dependency
            # (not just any actions that happen to be positioned after it)
            # This ensures we stack multiple actions that depend on the SAME dependency sequentially
            $ActionsAfterThisDependency = $This.Actions | Where-Object {
                # Only consider actions that actually depend on this specific dependency
                if($_.Dependency_Guid -eq $DependencyGuid -and $_.Action_Guid -match '^(\d+)-'){
                    $ThisOrder = [int]$Matches[1]
                    # Exclude temporary high prefixes (> 99000000)
                    return ($ThisOrder -lt 99000000)
                }
                return $false
            }
            
            if($ActionsAfterThisDependency){
                # Find the highest order among actions that depend on this same dependency
                $HighestAfterOrder = [int](($ActionsAfterThisDependency | ForEach-Object {
                    if($_.Action_Guid -match '^(\d+)-'){ [int]$Matches[1] }
                } | Measure-Object -Maximum).Maximum)
                
                $InsertAfterOrder = $HighestAfterOrder
            }
            
            ol v "Dependency is at order position: $DependencyOrder (from Action_Guid)"
            ol v "Inserting after position: $InsertAfterOrder"
            ol v "New action will be inserted at position: $($InsertAfterOrder + 1)"
            
            # Increment all actions at position (InsertAfterOrder + 1) and beyond to make room
            $InsertPosition = $InsertAfterOrder + 1
            $ActionsToIncrement = $This.Actions | Where-Object {
                if($_.Action_Guid -match '^(\d+)-'){
                    $ThisOrder = [int]$Matches[1]
                    # Increment actions at or after our insertion point
                    # Exclude temporary high prefixes (>= 99000000)
                    return ($ThisOrder -ge $InsertPosition -and $ThisOrder -lt 99000000)
                }
                return $false
            }
            
            if($ActionsToIncrement){
                ol v "Incrementing $(@($ActionsToIncrement).Count) existing action(s) to make room for insertion"
                $ActionsToIncrement | ForEach-Object {
                    if($_.Action_Guid -match '^(\d+)-(.+)$'){
                        $CurrentOrder = [int]$Matches[1]
                        $CurrentGuidPart = $Matches[2]
                        $NewOrder = $CurrentOrder + 1
                        $_.Action_Guid = '{0:d8}-{1}' -f $NewOrder, $CurrentGuidPart
                        ol v "  Incremented action from position $CurrentOrder to $NewOrder"
                    }
                }
            }
            
            # Generate a new unique GUID for this action
            # Keep the original GUID's unique part, just change the ordering prefix
            if($ActionGuid -notmatch '^(\d+)-(.+)$'){
                throw "Invalid ActionGuid format: $ActionGuid (expected format: 00000001-guid)"
            }
            $GuidPart = $Matches[2]
            ol v "The GUID part is: $GuidPart"
            $NewActionGuid = '{0:d8}-{1}' -f $InsertPosition, $GuidPart
            
            ol v "New Action GUID: $NewActionGuid"
            return $NewActionGuid
        }
        catch{
            throw $_
        }
    }

    [Void] IncrementActionOrdersFrom([int]$StartingOrder){
        <#
            When inserting an action at a specific order position, we need to increment
            all actions at or after that position to make room.
        #>
        try{
            $ActionsToIncrement = $This.Actions | Where-Object { 
                $null -ne $_.ActionOrder -and $_.ActionOrder -ge $StartingOrder 
            } | Sort-Object -Property ActionOrder -Descending
            
            foreach($Action in $ActionsToIncrement){
                $OldOrder = $Action.ActionOrder
                $Action.ActionOrder = $OldOrder + 1
                
                # Update the Action_Guid to reflect new order
                if($Action.Action_Guid -match '^(\d+)-(.+)$'){
                    $GuidPart = $Matches[2]
                    $Action.Action_Guid = "{0:D8}-{1}" -f $Action.ActionOrder, $GuidPart
                }
            }
        }
        catch{
            throw $_
        }
    }
}