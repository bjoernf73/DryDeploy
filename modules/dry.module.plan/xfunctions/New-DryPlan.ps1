<# 
    This module contains functions to resolve, get, modify and show a DryDeploy 
    Plan.  

    Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
   #>

function New-DryPlan{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $ResourcesFile,

        [Parameter(Mandatory)]
        [string]
        $PlanFile,

        [Parameter(Mandatory)]
        [string]
        $ArchiveFolder,

        [Parameter(Mandatory)]
        [PSObject]
        $Configuration,

        [Parameter(Mandatory)]
        [PSObject]
        $ConfigCombo,

        [Parameter()]
        [array]
        $ResourceNames,

        [Parameter()]
        [array]
        $ExcludeResourceNames,

        [Parameter()]
        [array]
        $RoleNames,

        [Parameter()]
        [array]
        $ExcludeRoleNames,

        [Parameter()]
        [array] 
        $ActionNames,

        [Parameter()]
        [array]
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
    $Resources = [Resources]::New($Configuration,$ConfigCombo,$false)
    $Resources.Save($ResourcesFile,$true,$ArchiveFolder)
    $Plan = [Plan]::New($Resources)
    $PlanFilter = [PlanFilter]::New($ResourceNames,$ExcludeResourceNames,$RoleNames,$ExcludeRoleNames,$ActionNames,$ExcludeActionNames,$Phases,$ExcludePhases,$BuildSteps,$ExcludeBuildSteps)
    $Plan.Actions.foreach({
        if($PlanFilter.InFilter($_.ResourceName,$_.Role,$_.Action,$_.Phase,$_.ActionOrder)){
            $_.PlanSelected = $true
        }
        else{
            $_.PlanSelected = $false
        }
        # However, always set applyselected to false
        $_.ApplySelected = $false
    })
    
    # Set the PlanOrder based on PlanSelected
    $Plan.ResolvePlanOrder($PlanFile)
    $Plan.Save($PlanFile,$true,$ArchiveFolder)
    return $Plan
}