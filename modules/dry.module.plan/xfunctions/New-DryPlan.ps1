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

function New-DryPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]
        $ResourcesFile,

        [Parameter(Mandatory)]
        [String]
        $PlanFile,

        [Parameter(Mandatory)]
        [String]
        $ArchiveFolder,

        [Parameter(Mandatory)]
        [PSObject]
        $Configuration,

        [Parameter(Mandatory)]
        [PSObject]
        $ConfigCombo,

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
        $BuildSteps,

        [Parameter()]
        [Int[]] 
        $ExcludeBuildSteps,

        [Parameter()]
        [Int[]] 
        $Phases,

        [Parameter()]
        [Int[]] 
        $ExcludePhases
    )
    
    $Resources = $null 
    $Resources = [Resources]::New($Configuration,$ConfigCombo)
    $Resources.Save($ResourcesFile,$true,$ArchiveFolder)
    $Plan = [Plan]::New($Resources)
    $PlanFilter = [PlanFilter]::New($ResourceNames,$ExcludeResourceNames,$RoleNames,$ExcludeRoleNames,$ActionNames,$ExcludeActionNames,$Phases,$ExcludePhases,$BuildSteps,$ExcludeBuildSteps)
    $Plan.Actions.foreach({
        if ($PlanFilter.InFilter($_.ResourceName,$_.Role,$_.Action,$_.Phase,$_.ActionOrder)) {
            $_.PlanSelected = $true
        }
        else {
            $_.PlanSelected = $false
        }
        # However, always set applyselected to false
        $_.ApplySelected = $false
    })
    
    # Set the PlanOrder based on PlanSelected
    $Plan.ResolvePlanOrder($PlanFile)
    $Plan.Save($PlanFile,$true)
    return $Plan
}