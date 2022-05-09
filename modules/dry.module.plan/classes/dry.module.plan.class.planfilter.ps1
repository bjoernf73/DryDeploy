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
