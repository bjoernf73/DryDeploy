using Namespace System.Collections.Generic
using Namespace System.Collections
class DryAction {
    [Int]             $ApplyOrder
    [Int]             $PlanOrder
    [Int]             $ActionOrder
    [String]          $Action
    [Int]             $Phase
    [String]          $Source
    [String]          $Description
    [String]          $Role 
    [Guid]            $Resource_Guid 
    [String]          $Action_Guid
    [String]          $ResourceName
    [PSCustomObject]  $Resource
    [String]          $Status
    [String]          $Dependency_Guid
    [String]          $Chained_Guid
    [String[]]        $Dependency_Guids
    [Bool]            $PlanSelected
    [Bool]            $ApplySelected
    [Bool]            $ResolvedActionOrder
    [PSCustomObject]  $Credentials
    [PSCustomObject]  $Depends_On


    # Create Action
    DryAction (
        [PSCustomObject]         $ActionObject,
        [Resource]                   $Resource,
        [Resources]                  $Resources,
        [Plan]                       $Plan) 
    {
        $This.ResolvedActionOrder  = $False
        $This.Action               = $ActionObject.Action
        $This.Description          = $ActionObject.Description
        $This.Role                 = $Resource.Role
        $This.ApplyOrder           = $Null
        $This.PlanOrder            = $Null
        $This.Resource_Guid        = $Resource.Resource_Guid 
        $This.Action_Guid          = $ActionObject.Action_Guid 
        $This.ResourceName         = $Resource.Name
        $This.Resource             = $Resource 
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

        # The Action may get it's files from the role repository or a base repository
        if ($ActionObject.Source) {
            if ($ActionObject.Source -in @('role','base')) {
                $This.Source = $ActionObject.Source
            }
            else {
                throw "An Action's Source property must be 'base', 'role' or null"
            }
        }
        else {
            $This.Source = 'role'
        }

        # Test if the Action is the first in Plan
        if ($Resources.IsThisFirstActionInPlan($This.Action_Guid)) {
            <#
                The first Action may resolve ActionOrder immediately. That will serve
                as a starting point for all other Actions to resolve their ActionOrder. 
                These Actions all need a Dependendy_Guid to resolve ActionOrder
            #>
            $This.ActionOrder         = 1
            $This.ResolvedActionOrder = $true
            $Plan.OrderCount          = 2
        }
        elseif ($Null -ne $ActionObject.depends_on) {
            # The Action has an explicit dependency
            if ($ActionObject.depends_on.dependency_type -notin 'first','last','every','numbered','chained') {
                throw "A dependency_type must be 'first', 'last', 'every', 'numbered' or 'chained'"
            }
           
            switch ($ActionObject.depends_on.dependency_type) {
                'first' {
                    # The Action will be executed only after the first occurence of the dependency_action
                    $This.Dependency_Guid  = $Plan.GetFirstDependencyActionGuid($ActionObject.depends_on)
                    $This.Action_Guid      = $Plan.ResolveActionGuid($This.Dependency_Guid,$This.Action_Guid)
                        
                }
                'last' {
                    # The Action will be executed only after the last occurance of the dependency_action
                    $This.Dependency_Guid  = $Plan.GetLastDependencyActionGuid($ActionObject.depends_on)
                    $This.Action_Guid      = $Plan.ResolveActionGuid($This.Dependency_Guid,$This.Action_Guid)
                }
                'every' {
                    # The action will be executed after every occurance of the dependency_action
                    $This.Dependency_Guids = $Plan.GetEveryDependencyActionGuid($ActionObject.depends_on)
                }
                'numbered' {
                    # The action will be executed only after the n'th occurance of the dependency_action
                    $This.Dependency_Guids = $Plan.GetNumberedDependencyActionGuid($ActionObject.depends_on)
                }
                'chained' {
                    # The action will be executed after every occurance of the previous_action
                    $This.Chained_Guid = $Resources.GetPreviuosDependencyActionGuid($This.Action_Guid)
                }
            } 
        }
    }

    # Create Action after Dependency_Action has been resolved
    DryAction (
        [PSCustomObject]             $ActionObject,
        [Resource]                   $Resource,
        [Resources]                  $Resources,
        [Plan]                       $Plan,
        [String]                     $Dependency_Guid,
        [String]                     $Action_Guid) {

        $This.ResolvedActionOrder  = $False
        $This.Action               = $ActionObject.Action
        $This.Description          = $ActionObject.Description
        $This.Role                 = $Resource.Role
        $This.ApplyOrder           = $Null
        $This.PlanOrder            = $Null
        $This.Resource_Guid        = $Resource.Resource_Guid
        $This.Action_Guid          = $Action_Guid
        $This.ResourceName         = $Resource.Name
        $This.Resource             = $Resource
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

        # The Action may get it's files from the role repository or a base repository
        if ($ActionObject.Source) {
            if ($ActionObject.Source -in @('role','base')) {
                $This.Source = $ActionObject.Source
            }
            else {
                throw "An Action's Source property must be 'base', 'role' or null"
            }
        }
        else {
            $This.Source = 'role'
        }

        $This.Action_Guid = $Plan.ResolveActionGuid($This.Dependency_Guid,$This.Action_Guid)
    }

    # Create Action after Dependency Chain has been resolved
    DryAction (
        [PSCustomObject]             $ActionObject,
        [String]                     $ActionGuid) {

        $This.ResolvedActionOrder  = $False
        $This.Action               = $ActionObject.Action
        $This.Description          = $ActionObject.Description
        $This.Role                 = $ActionObject.Role
        $This.ApplyOrder           = $Null
        $This.PlanOrder            = $Null
        $This.Resource_Guid        = $ActionObject.Resource_Guid
        $This.Action_Guid          = $ActionGuid
        $This.ResourceName         = $ActionObject.ResourceName
        $This.Resource             = $ActionObject.Resource
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

        # The Action may get it's files from the role repository or a base repository
        if ($ActionObject.Source) {
            if ($ActionObject.Source -in @('role','base')) {
                $This.Source = $ActionObject.Source
            }
            else {
                throw "An Action's Source property must be 'base', 'role' or null"
            }
        }
        else {
            $This.Source = 'role'
        }
    }

    # Create Action from file
    DryAction (
        [PSCustomObject]$ActionObject) {
        $This.ResolvedActionOrder  = $ActionObject.ResolvedActionOrder
        $This.ApplyOrder           = $Null # <-- Re-evaluated at every run
        $This.PlanOrder            = $ActionObject.PlanOrder
        $This.ActionOrder          = $ActionObject.ActionOrder
        $This.Resource_Guid        = $ActionObject.Resource_Guid
        $This.Action_Guid          = $ActionObject.Action_Guid
        $This.ResourceName         = $ActionObject.ResourceName
        $This.Resource             = $ActionObject.Resource
        $This.Status               = $ActionObject.Status
        $This.PlanSelected         = $ActionObject.PlanSelected
        $This.ApplySelected        = $False # <-- Re-evaluated at every run
        
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

class Plan {
    [ArrayList] $Actions
    [Bool]      $UnresolvedActions
    [ArrayList] $UnresolvedActionsList
    [Int]       $OrderCount
    [Int]       $ActiveActions
    [DateTime]  $PlannedTime  # updated any time you create or modify a plan
    [nullable[Datetime]]  $EndTime      # set in DryDeploy's finally - will be reset to null any time $PlannedTime is modified
    
    # New Plan Object
    Plan ([Resources] $Resources) {
        $This.Actions               = [ArrayList]::New()
        $This.UnresolvedActionsList = [ArrayList]::New()
        $This.OrderCount            = 1
        $This.ActiveActions         = 0
        $This.PlannedTime           = [DateTime](Get-Date)
        $This.EndTime               = $null
        
        # Loop backwards through the Resources
        for ($ResourceOrderCount = $($Resources.Resources).Count; $ResourceOrderCount -gt 0; $ResourceOrderCount-- ) {
            # Get the resource with ResourceOrder = $ResourceCount
            [Resource] $CurrentResource = $Resources.Resources | 
            Where-Object {
                $_.ResourceOrder -eq $ResourceOrderCount
            }

            # Loop backwards through the Actions
            for ($ActionOrderCount = ($CurrentResource.ActionOrder).Count; $ActionOrderCount -gt 0; $ActionOrderCount-- ) {
                [PSCustomObject] $CurrentAction = $CurrentResource.ActionOrder | 
                Where-Object {
                    $_.order -eq $ActionOrderCount
                }
                if ($Null -eq $CurrentAction) {
                    throw "Unable to find action order $ActionOrderCount on resource $($CurrentResource.Name)"
                }

                $ResolveUnresolvedActions = $False

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
                if ($Action.Dependency_Guids) {
                    foreach ($Dependency_Guid in $Action.Dependency_Guids) {
                        $Action = [DryAction]::New(
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

                if (($ResolveUnresolvedActions -eq $true) -and ($This.UnresolvedActionsList.Count -gt 0)) {
                    $This.ResolveUnresolvedActions()
                }
            }
        }
        # $This.ResolveActions()
        $This.AddActionOrder()
    }

    # Recreate Plan from file
    Plan ([String] $PlanFile) {
        $This.Actions               = [ArrayList]::New()
        $This.UnresolvedActionsList = [ArrayList]::New()
        $This.ActiveActions         = 0
        
        if (-not (Test-Path -Path $PlanFile -ErrorAction Ignore)) {
            throw "PlanFile not found: $PlanFile"
        }

        [PSCustomObject]$PlanObject = Get-Content -Path $PlanFile -Raw -ErrorAction Stop | 
        ConvertFrom-Json -ErrorAction Stop
        $This.OrderCount = $PlanObject.OrderCount
        $PlanObject.Actions.foreach({
            $This.Actions += [DryAction]::New($_)
        })
        $This.PlannedTime = [DateTime]($PlanObject.PlannedTime)
        if ($null -eq $PlanObject.EndTime) {
            $This.EndTime = $null
        }
        else {
            $This.EndTime = [DateTime]($PlanObject.PlannedTime)
        }
    }

    [Void] hidden ResolveUnresolvedActions() {
        try {
            $This.UnresolvedActionsList = @($This.UnresolvedActionsList | Sort-Object -Property Action_Guid)

            # Get each Action in Plan that the Unresolved (chained) Action depends on
            $This.UnresolvedActionsList.foreach({
                $DependencyGuid       = $_.Chained_Guid
                $ActionGuid           = $_.Action_Guid
                $DependentActionGuids = $This.GetEveryDependencyActionGuid($_.Chained_Guid)

                if ($DependentActionGuids.Count -eq 0) {
                    throw "Unable to find Dependent Action with Guid matching $DependencyGuid"
                }
                foreach ($DependentActionGuid in $DependentActionGuids) {
                    # get the action guid
                    $InstanceActionGuid = $This.ResolveActionGuid($DependentActionGuid,$ActionGuid) 
                    $This.Actions += [DryAction]::New($_,$InstanceActionGuid)
                }
            })
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
        $This.Save($PlanFile,$false,$null)
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
        $This.Save($PlanFile,$false,$null)
    }

    [Void] Save ($PlanFile,$Archive,$ArchiveFolder) {
        if ($Archive) {
            # Archive previous Plan-file and create new
            if (Test-Path -Path $PlanFile -ErrorAction SilentlyContinue) {
                ol v "ResourcesFile '$PlanFile' exists, archiving" 
                Save-DryArchiveFile -ArchiveFile $PlanFile -ArchiveFolder $ArchiveFolder
            }
        }
        
        ol v "Saving Planfile '$PlanFile'"
        Set-Content -Path $PlanFile -Value (ConvertTo-Json -InputObject $This -Depth 100) -Force
    }


    [String[]] GetEveryDependencyActionGuid (
        [PSObject] $DependencySpec) {

        $EveryDependencyActionGuid = $null
        $EveryDependencyActionGuid = @()
        $This.Actions.foreach({
            if ($null -eq $DependencySpec.Phase) {
                $DependencySpecPhase = 0
            }
            else {
                $DependencySpecPhase = $DependencySpec.Phase
            }
            if (($_.Role   -eq $DependencySpec.Role) -And 
                ($_.Action -eq $DependencySpec.Action) -And
                ($_.Phase  -eq $DependencySpecPhase)) {
                $EveryDependencyActionGuid += $_.Action_Guid
            }
        })
        return $EveryDependencyActionGuid
    }


    [String[]] GetEveryDependencyActionGuid (
        [String] $DependencyGuid) {

        $EveryDependencyActionGuid = $null
        $EveryDependencyActionGuid = @()
        $This.Actions.foreach({
            if ($_.Action_Guid -match "$DependencyGuid$") {
                $EveryDependencyActionGuid += $_.Action_Guid
            }
        })
        return $EveryDependencyActionGuid
    }


    [String] GetFirstDependencyActionGuid (
        [PSObject] $DependencySpec) {

        $EveryDependencyActionGuid = $null
        $EveryDependencyActionGuid = $This.GetEveryDependencyActionGuid($DependencySpec)
        if ($EveryDependencyActionGuid.Count -eq 0) {
            throw "Unable to find the Dependency Action Guid"
        }
        $EveryDependencyActionGuid = $EveryDependencyActionGuid | Sort-Object -ErrorAction Stop
        return $EveryDependencyActionGuid[0]
    }


    [String] GetLastDependencyActionGuid (
        [PSObject] $DependencySpec) {

        $EveryDependencyActionGuid = $null
        $EveryDependencyActionGuid = $This.GetEveryDependencyActionGuid($DependencySpec)
        if ($EveryDependencyActionGuid.Count -eq 0) {
            throw "Unable to find the Dependency Action Guid"
        }
        $EveryDependencyActionGuid = $EveryDependencyActionGuid | Sort-Object -Descending -ErrorAction Stop
        return $EveryDependencyActionGuid[0]
    }

    [String] GetNumberedDependencyActionGuid (
        [PSObject] $DependencySpec) {

        [Int]$DependencyNumberedActionOrder = ($DependencySpec.dependency_numbered_action)-1
        $EveryDependencyActionGuid = $null
        $EveryDependencyActionGuid = $This.GetEveryDependencyActionGuid($DependencySpec)
        if ($EveryDependencyActionGuid.Count -eq 0) {
            throw "Unable to find the Dependency Action Guid"
        }
        $EveryDependencyActionGuid = $EveryDependencyActionGuid | Sort-Object -ErrorAction Stop
        if ($null -eq $EveryDependencyActionGuid[$DependencyNumberedActionOrder]) {
            throw "There is no numbered dependency Action nr $($DependencySpec.dependency_numbered_action)"
        }
        return $EveryDependencyActionGuid[$DependencyNumberedActionOrder]
    }
    
    [String] ResolveActionGuid($DependencyGuid,$ActionGuid) {
        try {
            $DependencyAction = $null
            $DependencyAction = [ArrayList]::New()
            $DependecyActionCount = 0 
            $DashActualGuidPart = $ActionGuid.SubString(12)
            $This.Actions.foreach({
                if ($DependencyGuid -eq $_.Action_Guid) {
                    $DependencyAction.Add($_)
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