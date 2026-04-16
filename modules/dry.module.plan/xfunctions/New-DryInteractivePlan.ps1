<#
    This module contains functions to resolve, get, modify and show a DryDeploy
    Plan.

    Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/LICENSE
   #>

function New-DryInteractivePlan{
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

    $InteractiveIntro = "In interactive mode, you create a plan sporadically without having to specify resources in your environment (EnvConfig). For instance, you may use a module (ModuleConfig) of basic, non-specialized roles to rapidly get an instance of an OS up and running. While in non-interactive mode the role (or blueprint) decides the role's short name, in interactive mode you specify it. This may be practical if the role is a domain member, and the Active Directory configuration separates and categorizes different roles into OU's based on the role short name."
    ol i $InteractiveIntro
    ol i " "
    $Resources = $null
    $Resources = [Resources]::New($Configuration,$ConfigCombo,$true)
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