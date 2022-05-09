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