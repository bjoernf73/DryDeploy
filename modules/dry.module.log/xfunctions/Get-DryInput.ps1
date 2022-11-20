<# 
 This module is contains logging and console output functions for DryDeploy. 

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.query/main/LICENSE
 
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

<#
.SYNOPSIS
A logging and output-to-display module for DryDeploy

.DESCRIPTION
A logging and output-to-display module for DryDeploy

#>
function Get-DryInput {
    [CmdletBinding(DefaultParameterSetName="prompt")]
    param (
        [Parameter(ParameterSetName="prompt",Mandatory)]
        [String]$Prompt,

        [Parameter(ParameterSetName="prompt")]
        $DefaultValue,

        [Parameter(ParameterSetName="prompt",HelpMessage = "May be used for simple values like 
        a list of allowed numbers to choose from in a prompt. Will automatically be shown in 
        the prompt allowed values 'box' (in from of the prompt in [<here>])")]
        [String]$PromptChoiceString,

        [Parameter(ParameterSetName="prompt",
        HelpMessage="A helpmessage that is printed before the actual prompt")]
        [String]$Description,

        [Parameter(ParameterSetName="prompt",Mandatory)]
        [AllowEmptyString()]
        [String]$FailedMessage,

        [Parameter(HelpMessage="When there is a choice between options, use a ValidateSet to ensure input
        values are in the set of allowed choices")]
        [AllowEmptyString()]
        [Array]$ValidateSet,

        [Parameter(HelpMessage="A scriptblock to validate the user input. The scriptblock will be passed
        the `$ValidateScriptParams and the `$iInput as the last argument")]
        [scriptblock]$ValidateScript, 

        [array]$ValidateScriptParams

    )

    try {
        function Get-DryInputValidation {
            [cmdletbinding(DefaultParameterSetName = 'set')]
            param(
                [Parameter(Mandatory)]
                $iInput,

                [Parameter(Mandatory)]
                $FailedMessage,

                [Parameter(ParameterSetName="set")]
                $ValidateSet,

                [Parameter(Mandatory,ParameterSetName="script")]
                $ValidateScript,

                [Parameter(ParameterSetName="script")]
                $ValidateScriptParams
            )
            try {
                if ($null -eq $iInput) {
                    throw "goto catch"
                }
                else {
                    switch ($PSCmdlet.ParameterSetName) {
                        'set' {
                            if ($null -ne $ValidateSet) {
                                if ($iInput -in $ValidateSet) {
                                    return $true
                                }
                                else {
                                    throw "goto catch"
                                }
                            }
                            else {
                                # nothing to validate
                                return $true
                            }
                        }
                        'script' {
                            $ValidateScriptParams += $iInput
                            if (Invoke-Command -ScriptBlock $ValidateScript -ArgumentList $ValidateScriptParams) {
                                return $true
                            }
                            else {
                                throw "goto catch"
                            }
                        }
                    } 
                }
            }
            catch {
                ol w $FailedMessage
                return $false
            }
        }

        $LoggingOptions = $GLOBAL:LoggingOptions
        $FormattedMessage = $LoggingOptions.input.text_type
        if ($PromptChoiceString) {
            $PromptChoiceString = $PromptChoiceString.Trim()
        }
        else {
            $PromptChoiceString = "<value>"
        }
        
        # make sure left_column is a certain length
        while ($FormattedMessage.length -lt $LoggingOptions.left_column_width) {
            $FormattedMessage = $FormattedMessage + ' '
        }
        $FormattedMessage = $FormattedMessage + $Prompt + " [$PromptChoiceString or 'quit']"

        # Print the description
        if ($Description) {
            ol i $Description
            ol i ""
        }
        # start the prompt loop
        $WriteHostParams = @{
            NoNewLine = $true 
        }
        if ($LoggingOptions.input.foreground_color) {
            $WriteHostParams += @{
                ForegroundColor = $LoggingOptions.input.foreground_color
            }
        }
        if ($ValidateSet) {
            do {
                $FormattedMessage | Write-Host @WriteHostParams
                $DryInput = Read-Host -Prompt " "
                if (($null -ne $DefaultValue) -and ($DryInput.Trim() -eq '')) {
                    $DryInput = $DefaultValue
                }
                elseif ($DryInput -eq 'quit') {
                    break
                }
            }
            while (-not (Get-DryInputValidation -iInput $DryInput -ValidateSet $ValidateSet -FailedMessage $FailedMessage))
        }
        elseif ($ValidateScript) {
            do {
                $FormattedMessage | Write-Host @WriteHostParams 
                $DryInput = Read-Host -Prompt " "
                if (($null -ne $DefaultValue) -and ($DryInput.Trim() -eq '')) {
                    $DryInput = $DefaultValue
                }
                elseif ($DryInput -eq 'quit') {
                    break
                }
            }
            while (-not (Get-DryInputValidation -iInput $DryInput -ValidateScript $ValidateScript -ValidateScriptParams $ValidateScriptParams -FailedMessage $FailedMessage))
        }
        else {
            # no validation
            do {
                $FormattedMessage | Write-Host @WriteHostParams 
                $DryInput = Read-Host -Prompt " "
                if (($null -ne $DefaultValue) -and ($DryInput.Trim() -eq '')) {
                    $DryInput = $DefaultValue
                }
                elseif ($DryInput -eq 'quit') {
                    break
                }
                elseif ($null -eq $DryInput) {
                    # To make sure .trim() works
                    $DryInput = " "
                }
            }
            while (($DryInput.trim() -eq ''))
        }
        
        if ($DryInput -eq 'quit') {
            break
        }
        else {
            return $DryInput
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}