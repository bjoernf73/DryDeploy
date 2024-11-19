using Namespace System.Collections.Generic
using Namespace System.Collections
class PlanFilter {
    [String[]]$ResourceNames
    [String[]]$ExcludeResourceNames
    [String[]]$RoleNames
    [String[]]$ExcludeRoleNames
    [String[]]$ActionNames
    [String[]]$ExcludeActionNames
    [Int[]]$Phases
    [Int[]]$ExcludePhases
    [Int[]]$BuildSteps
    [Int[]]$ExcludeBuildSteps

    PlanFilter (
        [String[]]$ResourceNames,
        [String[]]$ExcludeResourceNames,
        [String[]]$RoleNames,
        [String[]]$ExcludeRoleNames,
        [String[]]$ActionNames,
        [String[]]$ExcludeActionNames,
        [Int[]]$Phases,
        [Int[]]$ExcludePhases,
        [Int[]]$BuildSteps,
        [Int[]]$ExcludeBuildSteps) {
            
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
        [string]$ResourceName,
        [string]$RoleName,
        [string]$ActionName,
        [int]$Phase,
        [int]$ActionOrder) {
        
        $ResourceValidated = $RoleValidated = $ActionValidated = $PhaseValidated = $ActionOrderValidated = $false
        
        # ResourceName
        if ($null -eq $This.ResourceNames) {
            $ResourceValidated = $true
        }
        elseif ($ResourceName -in $This.ResourceNames) {
            $ResourceValidated = $true
        }
        else {
            $NameMatch = $false
            $NameMatch = Invoke-Command -ScriptBlock {($This.ResourceNames).foreach({ if ($ResourceName -match "^$_") { $NameMatch = $true } }); $NameMatch}
            if ($NameMatch) {
                $ResourceValidated = $true
            }
        }

        # ExcludeResourceName
        if ($null -eq $This.ExcludeResourceNames) { # do nothin'
        }
        elseif ($ResourceName -in $This.ExcludeResourceNames) {
            $ResourceValidated = $false
        }
        else {
            $NameMatch = $false
            $NameMatch = Invoke-Command -Scriptblock {($This.ExcludeResourceNames).foreach({if ($ResourceName -match "^$_") {$NameMatch = $true}}); $NameMatch}
            if ($NameMatch) {
                $ResourceValidated = $false
            }
        }

        # RoleName
        if ($null -eq $This.RoleNames) {
            $RoleValidated = $true
        }
        elseif ($RoleName -in $This.RoleNames) {
            $RoleValidated = $true
        }
        else {
            $NameMatch = $false
            $NameMatch = Invoke-Command -Scriptblock {($This.RoleNames).foreach({if ($RoleName -match "^$_") {$NameMatch = $true}}); return $NameMatch}
            if ($NameMatch) {
                $RoleValidated = $true
            }
        }

        # ExcludeRoleName
        if ($null -eq $This.ExcludeRoleNames) { # do nothin'  
        }
        elseif ($RoleName -in $This.ExcludeRoleNames) {
            $RoleValidated = $false
        }
        else {
            $NameMatch = $false
            $NameMatch = Invoke-Command -Scriptblock {($This.ExcludeRoleNames).foreach({if ($RoleName -match "^$_") {$NameMatch = $true}}); return $NameMatch}
            if ($NameMatch) {
                $RoleValidated = $false
            }
        }

        # ActionName
        if ($null -eq $This.ActionNames) {
            $ActionValidated = $true
        }
        elseif ($ActionName -in $This.ActionNames) {
            $ActionValidated = $true
        }
        else {
            $NameMatch = $false
            $NameMatch = Invoke-Command -Scriptblock {($This.ActionNames).foreach({if ($ActionName -match "^$_") {$NameMatch = $true}}); return $NameMatch} 
            if ($NameMatch) {
                $ActionValidated = $true 
            }
        }

        # ExcludeActionName
        if ($null -eq $This.ExcludeActionNames) { # Do nothing
        }
        elseif ($ActionName -in $This.ExcludeActionNames) {
            $ActionValidated = $false
        }
        else {
            $NameMatch = $false
            $NameMatch = Invoke-Command -Scriptblock {($This.ExcludeActionNames).foreach({if ($ActionName -match "^$_") {$NameMatch = $true}}); return $NameMatch}
            if ($NameMatch) {
                $ActionValidated = $false 
            }
        }

        # Phase
        if ($null -eq $This.Phases) {
            $PhaseValidated = $true
        }
        elseif ($Phase -in $This.Phases) {
            $PhaseValidated = $true
        }

        # ExcludePhase
        if ($null -eq $This.ExcludePhases) {
            # do nothin'
        }
        elseif ($Phase -in $This.ExcludePhases) {
            $PhaseValidated = $false
        }

        # ActionOrder
        if ($null -eq $This.BuildSteps) {
            $ActionOrderValidated = $true
        }
        elseif ($ActionOrder -in $This.BuildSteps) {
            $ActionOrderValidated = $true
        }

        # ExcludeActionOrder
        if ($null -eq $This.ExcludeBuildSteps) {
            # do nothin'
        }
        elseif ($ActionOrder -in $This.ExcludeBuildSteps) {
            $ActionOrderValidated = $false
        }

        # return true only if all are validated, false if not
        if ($ResourceValidated -and 
            $RoleValidated -and
            $ActionValidated -and 
            $PhaseValidated -and
            $ActionOrderValidated) {
            return $true
        }
        else {
            return $false
        }
    }
}