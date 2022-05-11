<# 
    This module contains functions to resolve, get, modify and show a DryDeploy 
    Plan.  

    Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
    
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

function Get-DryPlan {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]
        $PlanFile,

        [Parameter()]
        [Array]
        $ResourceNames,

        [Parameter()]
        [Array]
        $ExcludeResourceNames,

        [Parameter()]
        [Array]
        $RoleNames,

        [Parameter()]
        [Array]
        $ExcludeRoleNames,

        [Parameter()]
        [Array]
        $ActionNames,

        [Parameter()]
        [Array] 
        $ExcludeActionNames,

        [Parameter()]
        [Int[]]
        $Phases,

        [Parameter()]
        [Int[]]
        $ExcludePhases,

        [Parameter()]
        [Int[]]
        $BuildSteps,

        [Parameter()]
        [Int[]]
        $ExcludeBuildSteps,

        [Parameter(HelpMessage="Changes status 'Retrying' back to 'Failed'")]
        [Switch]
        $ShowStatus
    )

    $Plan = [Plan]::New($PlanFile)
    $PlanFilter = [PlanFilter]::New($ResourceNames,$ExcludeResourceNames,$RoleNames,$ExcludeRoleNames,$ActionNames,$ExcludeActionNames,$Phases,$ExcludePhases,$BuildSteps,$ExcludeBuildSteps)
    <#
        At runtime (i.e. when you -Apply), selections made by the the parameters -Resources, 
        -Roles, -Actions and -Phases, are only applied to actions that are already selected in the 
        current Plan (i.e. when you -Plan). At each -Apply, the ApplySelected is reevaluated. 
    #>
    $Plan.Actions.foreach({
        if ($_.PlanSelected -eq $True) {
            if ($PlanFilter.InFilter($_.ResourceName,$_.Role,$_.Action,$_.Phase,$_.ActionOrder)) {
                $_.ApplySelected = $True
                if ($ShowStatus) {  # If the Action was previously 'Retrying', change to 'Failed' if $ShowStatus
                    if ($_.Status -eq 'Retrying') {
                        $_.Status = 'Failed'
                    }
                }
            }
            else {
                $_.ApplySelected = $False
            }
            if ($_.Status -eq 'Success') {  # However, if the Action has a status of 'Success', deselect
                $_.ApplySelected = $false
            }
        }
        else {
            $_.ApplySelected = $false
        }
    })
    $Plan.ResolveApplyOrder($PlanFile) # Set the ApplyOrder based on PlanSelected
    $Plan.ActiveActions = 0            # Set ApplyOrder and number of active actions
    $Plan.Actions.foreach({
        if ($_.ApplySelected -eq $True) {
            $Plan.ActiveActions++
        }
    })
    
    $Plan.Save($PlanFile,$False)
    return $Plan
}