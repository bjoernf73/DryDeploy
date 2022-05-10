using Namespace System.Collections.Generic
using Namespace System.Collections
class PlanFilter {
    [String[]] $ResourceNames
    [String[]] $ExcludeResourceNames
    [String[]] $RoleNames
    [String[]] $ExcludeRoleNames
    [String[]] $ActionNames
    [String[]] $ExcludeActionNames
    [Int[]]    $Phases
    [Int[]]    $ExcludePhases
    [Int[]]    $BuildSteps
    [Int[]]    $ExcludeBuildSteps

    PlanFilter (
        [String[]] $ResourceNames,
        [String[]] $ExcludeResourceNames,
        [String[]] $RoleNames,
        [String[]] $ExcludeRoleNames,
        [String[]] $ActionNames,
        [String[]] $ExcludeActionNames,
        [Int[]]    $Phases,
        [Int[]]    $ExcludePhases,
        [Int[]]    $BuildSteps,
        [Int[]]    $ExcludeBuildSteps) {
            
        $This.ResourceNames        = $ResourceNames
        $This.ExcludeResourceNames = $ExcludeResourceNames
        $This.RoleNames            = $RoleNames
        $This.ExcludeRoleNames     = $ExcludeRoleNames
        $This.ActionNames          = $ActionNames
        $This.ExcludeActionNames   = $ExcludeActionNames
        $This.Phases               = $Phases
        $This.ExcludePhases        = $ExcludePhases
        $This.BuildSteps           = $BuildSteps
        $This.ExcludeBuildSteps    = $ExcludeBuildSteps
    }

    [Bool] Hidden InFilter(
        [String] $ResourceName,
        [String] $RoleName,
        [String] $ActionName,
        [Int]    $Phase,
        [Int]    $ActionOrder) {
        
        $ResourceValidated = $RoleValidated = $ActionValidated = $PhaseValidated = $ActionOrderValidated = $False
        
        # ResourceName
        if ($Null -eq $This.ResourceNames) {
            $ResourceValidated = $True
        }
        elseif ($ResourceName -in $This.ResourceNames) {
            $ResourceValidated = $True
        }
        else {
            $NameMatch = $false
            if ({($This.ResourceNames).foreach({if ($ResourceName -match "^$_") {$NameMatch = $true}}); return $NameMatch}) {
                $ResourceValidated = $true
            }
        }

        # ExcludeResourceName
        if ($Null -eq $This.ExcludeResourceNames) {
            # do noting
        }
        elseif ($ResourceName -in $This.ExcludeResourceNames) {
            $ResourceValidated = $False
        }
        else {
            $NameMatch = $false
            if ({($This.ExcludeResourceNames).foreach({if ($ResourceName -match "^$_") {$NameMatch = $true}}); return $NameMatch}) {
                $ResourceValidated = $false
            }
        }

        # RoleName
        if ($Null -eq $This.RoleNames) {
            $RoleValidated = $True
        }
        elseif ($RoleName -in $This.RoleNames) {
            $RoleValidated = $True
        }
        else {
            $NameMatch = $false
            if ({($This.RoleNames).foreach({if ($RoleName -match "^$_") {$NameMatch = $true}}); return $NameMatch}) {
                $RoleValidated = $true
            }
        }

        # ExcludeRoleName
        if ($Null -eq $This.ExcludeRoleNames) {
            # do noting
        }
        elseif ($RoleName -in $This.ExcludeRoleNames) {
            $RoleValidated = $False
        }
        else {
            $NameMatch = $false
            if ({($This.ExcludeRoleNames).foreach({if ($RoleName -match "^$_") {$NameMatch = $true}}); return $NameMatch}) {
                $RoleValidated = $false
            }
        }

        # ActionName
        if ($Null -eq $This.ActionNames) {
            $ActionValidated = $True
        }
        elseif ($ActionName -in $This.ActionNames) {
            $ActionValidated = $True
        }
        else {
            $NameMatch = $false
            if ({($This.ActionNames).foreach({if ($ActionName -match "^$_") {$NameMatch = $true}}); return $NameMatch}) {
                $ActionValidated = $true 
            }
        }

        # ExcludeActionName
        if ($Null -eq $This.ExcludeActionNames) {
            # Do nothing
        }
        elseif ($ActionName -in $This.ExcludeActionNames) {
            $ActionValidated = $False
        }
        else {
            $NameMatch = $false
            if ({($This.ExcludeActionNames).foreach({if ($ActionName -match "^$_") {$NameMatch = $true}}); return $NameMatch}) {
                $ActionValidated = $false 
            }
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
        if ($ResourceValidated -and 
            $RoleValidated -and
            $ActionValidated -and 
            $PhaseValidated -and
            $ActionOrderValidated) {
            return $True
        }
        else {
            return $False
        }
    }
}