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

        [Parameter(ParameterSetName="prompt",Mandatory,
        HelpMessage="A helpmessage that is printed before the actual prompt")]
        [String]$Description,

        [Parameter(ParameterSetName="prompt",Mandatory)]
        [AllowEmptyString()]
        [String]$FailedMessage,

        [Parameter(HelpMessage="When there is a choice between options, use a ValidateSet to ensure input
        values are in the set of allowed choices")]
        [AllowEmptyString()]
        [Array]$ValidateSet
    )

    try {
        function Get-DryInputApproval {
            [cmdletbinding()]
            param(
                $iInput,
                $ValidateSet,
                $FailedMessage
            )
            try {
                if ($null -eq $iInput) {
                    throw "goto catch"
                }
                if ($ValidateSet) {
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
            catch {
                ol w $FailedMessage
                return $false
            }
        }

        $LoggingOptions = $GLOBAL:LoggingOptions
        $TextType = 'INPUT:  '
        $FormattedMessage = $TextType 
        # make sure left_column is a certain length
        while ($FormattedMessage.length -lt $LoggingOptions.left_column_width) {
            $FormattedMessage = $FormattedMessage + ' '
        }
        $FormattedMessage = $FormattedMessage + $Prompt + " [ or 'quit']"

        # Print the description
        if ($Description) {
            ol i $Description
            ol i ""
        }
        # start the prompt loop
        Write-Host "ValidateSet is: $ValidateSet"
        do {
            $DryInput = Read-Host -Prompt $FormattedMessage
            if ($DryInput -eq 'quit') {
                break
            }
        }
        while (-not (Get-DryInputApproval -iInput $DryInput -ValidateSet $ValidateSet -FailedMessage $FailedMessage))

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