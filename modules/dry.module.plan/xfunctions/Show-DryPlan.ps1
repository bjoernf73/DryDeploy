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

function Show-DryPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Plan] $Plan,

        [Parameter(Mandatory)]
        [ValidateSet('Plan','Apply')]
        [String] $Mode,

        [Parameter(HelpMessage='Shows deselected Actions (not in Plan) as well as planned Actions')]
        [Switch]$ShowDeselected,

        [Parameter(HelpMessage='Shows the ConfigCombo paths as well as the Plan')]
        [Switch]$ShowConfigCombo,

        [Parameter()]
        [PSObject] $ConfigCombo
    )

    function Format-DryDescriptionString {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [AllowEmptyString()]  
            [String]$String, 

            [Int]$Offset,

            [Int]$Postbuffer = 3
        )
        try {
            $TargetMessageLength = $Host.UI.RawUI.WindowSize.Width - ($OffSet + $GLOBAL:LoggingOptions.left_column_width + $Postbuffer)
            If ($TargetMessageLength -lt 10) {
                If (($GLOBAL:dry_var_global_WarnOnTooNarrowConsole -eq $true) -or ($null -eq $GLOBAL:dry_var_global_WarnOnTooNarrowConsole)) {
                    ol w "Increase console width for messages to display properly"
                    $GLOBAL:dry_var_global_WarnOnTooNarrowConsole = $false
                }
                $TargetMessageLength = 10
            } 
        }
        catch {
            If (($GLOBAL:dry_var_global_WarnOnTooNarrowConsole -eq $true) -or ($null -eq $GLOBAL:dry_var_global_WarnOnTooNarrowConsole)) {
                ol w "Increase console width for messages to display properly"
                $GLOBAL:dry_var_global_WarnOnTooNarrowConsole = $false
            }
            $TargetMessageLength = 10
        }
        
        try {
            if ($String.Length -le $TargetMessageLength) {
                $String
            }
            else {
                $String.Substring(0,($TargetMessageLength-3)) + '...'
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }


    function Get-DryConfigComboString {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [String]$RepoType,

            [Parameter(Mandatory)]
            [String]$Path,

            [Int]$LongestResourceString
        )
        [String]$RepoString = ''
        [Int]$RepoTypeStringLength = $LongestResourceString + 11
        [String]$RepoString = $RepoType
        do {
            $RepoString = "$RepoString "
        } while ($RepoString.length -le $RepoTypeStringLength)
        [String]$RepoString = $RepoString + $Path
        $RepoString
    }

    function Get-DryPlanString {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [psobject]$Action,

            [Int]$LongestActionString,

            [Int]$LongestResourceString,

            [Int]$LongestRoleString,

            [Switch]$ShowDeslected
        )
 
        if ($Action.Phase -eq 0) {
            $Action.Phase = " "
        }
        # PlanO is exactly 5 chars. If it is 0, make empty
        [String]$OrderStr = $Action.PlanO  
        if ($OrderStr -eq '0') {
            [String]$OrderStr = ' '
        }
        While ($OrderStr.length -lt 5) {
            $OrderStr = "$OrderStr "
        }
        $PlanString += $OrderStr

        # resource is 3 chars more than $LongestResourceString
        [String]$ResourceStr = $Action.Resource  
        $ResourceStr = "   $ResourceStr"
        Do {
            $ResourceStr = "$ResourceStr "
        } 
        While ($ResourceStr.length -le ($LongestResourceString+6))
        $PlanString = $PlanString + $ResourceStr

        # action is 3 chars more than $LongestActionString
        [String]$ActionStr = $Action.Action
        Do {
            $ActionStr = "$ActionStr "
        } 
        While ($ActionStr.length -le ($LongestActionString+3))
        $PlanString = $PlanString + $ActionStr

        # Phase is 7 chars exactly
        [String]$PhaseStr = $action.Phase
        Do {
            $PhaseStr = "$PhaseStr "
        } 
        While ($PhaseStr.length -le 7)
        $PlanString = $PlanString + $PhaseStr

         # Role is 3 chars more than $LongestRoleString
         [String]$RoleStr = $Action.Role
         Do {
             $RoleStr = "$RoleStr "
         } 
         While ($RoleStr.length -le ($LongestRoleString+3))
         $PlanString = $PlanString + $RoleStr

        [String]$StatusStr = $action.Status
        Do {
            $StatusStr = "$StatusStr "
        } 
        While ($StatusStr.length -le 9)
        $PlanString = $PlanString + $StatusStr

        $PlanString = "$PlanString   "

        [String]$OrderStr = $Action.ActionO
        if ($OrderStr -eq '0') {
            [String]$OrderStr = ' '
        }
        While ($OrderStr.length -lt 8){
            $OrderStr = "$OrderStr "
        }
        $PlanString += $OrderStr
        
        # Description must be calculated
        [String]$DescStr = Format-DryDescriptionString -String $Action.Description -Offset ($PlanString.length)
        $PlanString = $PlanString + $DescStr
        
        # return the string
        $PlanString
    }
    
    # strings that will equal the length of the longest action names and resource name
    # set initial values so length exceeds header names ('RESOURCE' and 'ACTION')
    $LongestActionString   = 10
    $LongestResourceString = 8
    $LongestRoleString     = 20
    $NumberOfActions       = 0

    $Plan.Actions | 
    foreach-Object {
        $NumberOfActions++
        
        if ($LongestResourceString -lt ($_.ResourceName).length) {
            $LongestResourceString = ($_.ResourceName).length
        }
        
        if ($LongestActionString -lt ($_.Action).length) {
            $LongestActionString = ($_.Action).length
        }

        if ($LongestRoleString -lt ($_.Role).length) {
            $LongestRoleString = ($_.Role).length
        }
    }

    $PlanArray = @()   # Actions that are in Plan, but not selected during -Apply, or -Apply is noty run yet
    $NoPlanArray = @() # Actions that are in not in Plan

    for ($ActionOrderIndex = 1; $ActionOrderIndex -le $NumberOfActions; $ActionOrderIndex++) {

        $CurrentAction = $Plan.Actions | 
        Where-Object { 
            $_.ActionOrder -eq $ActionOrderIndex 
        }

        if ($null -eq $CurrentAction){
            throw "Found no action with index $ActionOrderIndex"
        }
        else {
            ol d "Found action with index $ActionOrderIndex ($($CurrentAction.ResourceName) - $($CurrentAction.Action))"
        }

        if ($CurrentAction.ApplySelected) {
            $PlanArray+= [PSCustomObject]@{
                Order       = $CurrentAction.ApplyOrder
                PlanO       = $CurrentAction.PlanOrder
                ActionO     = $CurrentAction.ActionOrder
                Resource    = $CurrentAction.ResourceName
                Action      = $CurrentAction.Action
                Phase       = $CurrentAction.Phase
                Role        = $CurrentAction.Role
                Status      = $CurrentAction.Status
                Description = $CurrentAction.Description
            }
        }
        elseif ($CurrentAction.PlanSelected) {
            $PlanArray+= [PSCustomObject]@{
                Order       = 0
                PlanO       = $CurrentAction.PlanOrder
                ActionO     = $CurrentAction.ActionOrder
                Resource    = $CurrentAction.ResourceName
                Action      = $CurrentAction.Action
                Phase       = $CurrentAction.Phase
                Role        = $CurrentAction.Role
                Status      = $CurrentAction.Status
                Description = $CurrentAction.Description
            }
        }
        else {
            $NoPlanArray+= [PSCustomObject]@{
                Order       = 0
                PlanO       = 0
                ActionO     = $CurrentAction.ActionOrder
                Resource    = $CurrentAction.ResourceName
                Action      = $CurrentAction.Action
                Phase       = $CurrentAction.Phase
                Role        = $CurrentAction.Role
                Status      = $CurrentAction.Status
                Description = $CurrentAction.Description
            }
        }
    }

    $ConfigComboHeader = [PSCustomObject]@{
        RepoType    = 'Config'
        Path        = 'Path'
    }

    $ConfigComboLine = [PSCustomObject]@{
        RepoType    = '........'
        Path        = '....'
    }
    
    $Header = [PSCustomObject]@{
        PlanO       = 'Plan#'
        Resource    = 'Resource'
        Action      = 'Action'
        Phase       = 'Phase'
        Role        = 'Role'
        Status      = 'Status'
        ActionO     = 'Build#'
        Description = 'Description'
    }

    $Headerline = [PSCustomObject]@{
        PlanO       = '.' * $Header.PlanO.length
        Resource    = '.' * $Header.Resource.length
        Action      = '.' * $Header.Action.length
        Phase       = '.' * $Header.Phse.length
        Role        = '.' * $Header.Role.length
        Status      = '.' * $Header.Status.length
        ActionO     = '.' * $Header.ActionO.length
        Description = '.' * $Header.Description.length
    }

    $Separatorline = [PSCustomObject]@{
        PlanO       = ' ' * $Header.PlanO.length
        Resource    = '.' * $Header.Resource.length
        Action      = ' ' * $Header.Action.length
        Phase       = ' ' * $Header.Phse.length
        Role        = ' ' * $Header.Role.length
        Status      = ' ' * $Header.Status.length
        ActionO     = ' ' * $Header.ActionO.length
        Description = ' ' * $Header.Description.length
    }

    if ($ShowConfigCombo) {
        ol i " "
        ol i $(Get-DryConfigComboString -LongestResourceString $LongestResourceString -RepoType $ConfigComboHeader.RepoType -Path $ConfigComboHeader.Path) -Fore DarkGray
        ol i $(Get-DryConfigComboString -LongestResourceString $LongestResourceString -RepoType $ConfigComboLine.RepoType -Path $ConfigComboLine.Path) -Fore DarkGray
        ol i $(Get-DryConfigComboString -LongestResourceString $LongestResourceString -RepoType 'EnvConfig' -Path $ConfigCombo.EnvConfig.Path) -Fore DarkGray
        ol i $(Get-DryConfigComboString -LongestResourceString $LongestResourceString -RepoType 'ModuleConfig' -Path $ConfigCombo.ModuleConfig.Path) -Fore DarkGray
        ol i " " 
        ol i " "
    }
    
    if ($PlanArray.count -gt 0) {
        
        ol i " "
        switch ($Mode) {
            'Plan' {
                ol i "Plan" -sh -air
                ol i " " 
            }
            'Apply' {
                ol i "Apply" -sh -air
                ol i " "
            }
            default {
                ol i "." -sh
                ol i " "
            }
        }
        
        ol i $(Get-DryPlanString -action $Header -LongestActionString $LongestActionString -LongestResourceString $LongestResourceString -LongestRoleString $LongestRoleString)
        ol i $(Get-DryPlanString -action $Headerline -LongestActionString $LongestActionString -LongestResourceString $LongestResourceString -LongestRoleString $LongestRoleString)
        $ResourceString = ''
        foreach ($Action in $PlanArray) {
            if (
                ($Action.Resource -ne $ResourceString) -And 
                ($ResourceString -ne '')
            ) {
                ol i $(Get-DryPlanString -action $Separatorline -LongestActionString $LongestActionString -LongestResourceString $LongestResourceString -LongestRoleString $LongestRoleString)
            }
            $ResourceString = $Action.Resource
            
            if ($Action.Status -eq 'Failed') {
                $Fore = [System.ConsoleColor]'Red'
            }
            elseif ($Action.Status -eq 'Success') {
                $Fore = [System.ConsoleColor]'Green'
            }
            elseif ($Action.Status -eq 'Retrying') {
                $Fore = [System.ConsoleColor]'DarkYellow'
            }
            elseif ($Action.Status -eq 'Starting') {
                $Fore = [System.ConsoleColor]'Yellow'
            }
            elseif ($Action.Order -eq 0) {
                switch ($Mode) {
                    'Plan' {
                        $Fore = [System.ConsoleColor]'White'
                    }
                    default {
                        $Fore = [System.ConsoleColor]'DarkGray'
                    }
                }
            }
            else {
                $Fore = [System.ConsoleColor]'White'
            }
            
            ol i $(Get-DryPlanString -action $Action -LongestActionString $LongestActionString -LongestResourceString $LongestResourceString -LongestRoleString $LongestRoleString) -Fore $Fore
        }
    }

    # Show Actions not in plan only if $ShowDeselected
    if ($ShowDeselected) {
        if ($NoPlanArray.count -gt 0) {
            ol i " "
            ol i " "
            ol i "Deselected" -sh -air -Fore 'DarkGray'
            ol i " "
            ol i $(Get-DryPlanString -action $Header -LongestActionString $LongestActionString -LongestResourceString $LongestResourceString -LongestRoleString $LongestRoleString) -Fore 'DarkGray'
            ol i $(Get-DryPlanString -action $Headerline -LongestActionString $LongestActionString -LongestResourceString $LongestResourceString -LongestRoleString $LongestRoleString) -Fore 'DarkGray'
            foreach ($Action in $NoPlanArray) {
                ol i $(Get-DryPlanString -action $Action -LongestActionString $LongestActionString -LongestResourceString $LongestResourceString -LongestRoleString $LongestRoleString) -Fore 'DarkGray'
            }
        }
    }
    ol i -h "" 
}