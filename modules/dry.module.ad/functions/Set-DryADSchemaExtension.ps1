Using Namespace System.Management.Automation.Runspaces
Using Namespace System.Collections.Generic
<#  
    This is an AD Config module for use with DryDeploy, or by itself.
    Copyright (C) 2021  Bjørn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.ad/main/LICENSE

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
function Set-DryADSchemaExtension {
    [CmdletBinding(DefaultParameterSetName = 'Local')] 
    param (
        [Parameter(Mandatory, HelpMessage = 'The Schema Extension type')]
        [String]
        $Type,

        [Parameter(Mandatory, HelpMessage = 'The number of times the success strings
        must be matched')]
        [Int]
        $SuccessCount,

        [Parameter(Mandatory, HelpMessage = 'The LDF Content')]
        [String]
        $Content,

        [Parameter(HelpMessage = 'Variables used for replacements in LDFs. Each 
        `$var.name will be wrapped in trippel hashes (###$($var.name)###) and
        any match replaced with $var.value')]
        [List[PSObject]]
        $Variables,

        [Parameter(Mandatory, ParameterSetName = 'Remote', HelpMessage = "PSSession 
        to run the script blocks in")]
        [PSSession] 
        $PSSession,

        [Parameter(Mandatory, HelpMessage = "The Schema Master")]
        [String] 
        $SchemaMaster
    )
    try {
        ol v @('Execution Type', "$($PSCmdlet.ParameterSetName)")

        $SuccessStrings = @(
            'Entry modified successfully.',
            'Entry already exists, entry skipped',
            'Attribute or value exists, entry skipped.',
            'The command has completed successfully'
        )

        # Loop through variables and replace patterns in LDF Content
        if ($Variables) {
            foreach ($Var in $Variables) {
                $Content = $Content -Replace "###$($Var.Name)###", "$($Var.Value)"
            }
        }

        # Trim start of each line
        $Content = ($Content -Split "`n" | foreach-Object { $_.TrimStart() } ) -join "`n"

        $ExtendSchemaArgumentList = @(
            $Content,
            $SchemaMaster
        )
        $InvokeSchemaExtensionParams = @{
            ScriptBlock  = $DryAD_SB_SchemaExtension_Set
            ArgumentList = $ExtendSchemaArgumentList
            ErrorAction  = 'Stop'
        }
        if ($PSCmdlet.ParameterSetName -eq 'Remote') {
            $InvokeSchemaExtensionParams += @{
                Session = $PSSession
            }
        }
        $ExtendSchemaResult = Invoke-Command @InvokeSchemaExtensionParams
        
        if ($ExtendSchemaResult[0] -eq '') {
            $MatchCount = 0
            $ExtendSchemaResult[1].foreach({ 
                    $CurrentString = $_; 
                    $SuccessStrings.foreach({ 
                            if ($CurrentString -Match $_) { 
                                $MatchCount++
                            } 
                        })
                })
            if ($MatchCount -eq $SuccessCount) {
                ol s "AD Schema is extended"
                ol i @('Successfully extended AD Schema of Type', $Type)
            }
            else {
                ol f "AD Schema not extended"
                ol w @("Target successcount $SuccessCount, actual", "$MatchCount")
                # Display thesult in debug
                $ExtendSchemaResult[1].foreach({
                        ol d $_
                    })
                throw "Schema extension failed"
            }
        }
        else {
            ol f "AD Schema not extended"
            ol e "Schema extension failed"
            throw $ExtendSchemaResult[0]
        }  
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
