Using Namespace System.Management.Automation.Runspaces
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
function Import-DryADGPO {
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    param (
        [Parameter(Mandatory)]
        [PSObject]
        $GPO,

        [Parameter(Mandatory)]
        [String]
        $GPOsPath,

        [Parameter()]
        [ValidateSet('domain', 'site', 'computer')]
        [String]
        $Scope = 'domain',

        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [PSSession]$PSSession,

        [Parameter(Mandatory, ParameterSetName = 'Local',
            HelpMessage = "For 'Local' sessions, specify the Domain Controller to use")]
        [String]
        $DomainController,

        [Parameter()]
        [HashTable]
        $ReplacementHash,

        [Parameter(HelpMessage = "Renames existing GPO, and removes all it's links")]
        [Switch]
        $Force
    )

    if ($PSCmdlet.ParameterSetName -eq 'Remote') {
        $Server = 'localhost'
        ol v @('Session Type', 'Remote')
        ol v @('Remoting to Domain Controller', "$($PSSession.ComputerName)")
    }
    else {
        $Server = $DomainController
        ol v @('Session Type', 'Local')
        ol v @('Using Domain Controller', "$Server")
    }

    ol v @('GPO Name', "'$($GPO.TargetName)'")
    ol v @('GPO Type', "'$($GPO.Type)'")
    
    switch ($GPO.type) {
        'backup' {
            $BackupGPOPath = Join-Path -Path $GPOsPath -ChildPath $GPO.Name
            ol v @('GPO Folder Path', "'$BackupGPOPath'")

            $GPOImportArgumentList = @(
                [String] $GPO.Name,
                [String] $GPO.TargetName,
                [String] $BackupGPOPath,
                [HashTable]$ReplacementHash
                [String] $Server,
                [Bool] $Force
            )

            $InvokeCommandParams = @{
                ScriptBlock  = $DryAD_SB_BackupGPO_Import
                ArgumentList = $GPOImportArgumentList
                ErrorAction  = 'Continue'
            }

            if ($PSCmdlet.ParameterSetName -eq 'Remote') {
                $InvokeCommandParams += @{
                    Session = $PSSession
                }
            }
            $GPOImportResult = $Null
            $GPOImportResult = Invoke-Command @InvokeCommandParams
            
            # Log all remote messages to Out-DryLog regardless of result
            foreach ($ResultMessage in $GPOImportResult[2]) {
                ol d "[BACKUPGPO] $ResultMessage"
            }

            if ($GPOImportResult[0] -eq $true) {
                ol v @('Successful import of backup GPO', "'$($GPO.Name)'")
            }
            else {
                ol e "Failed to import backup GPO $($GPO.Name): $($GPOImportResults[1].ToString())"
                throw "Failed to import backup GPO $($GPO.Name): $($GPOImportResults[1].ToString())"
            }
        }
        'json' {
            # GPO in json-format
            $JsonGPOFilePath = Join-Path -Path $GPOsPath -ChildPath "$($GPO.Name).json"
            ol v @('GPO File Path', "'$JsonGPOFilePath'")

            # Unless the json-gpo specifies a (bool) value for defaultpermissions, it is set to true, meaning
            # meaning that permissions in the json-GPO is ignored, and the default security descriptor of the 
            # groupPolicyContainer schema class is used.      
            if ($Null -eq $GPO.defaultpermissions) {
                [Bool]$GPODefaultPermissions = $true
            }
            else {
                [Bool]$GPODefaultPermissions = $GPO.defaultpermissions
            }

            $GPOImportArgumentList = @(
                [String]    $GPO.TargetName,
                [String]    $JsonGPOFilePath,
                [String]    $Server,
                [Bool]      $Force,
                [Bool]      $GPODefaultPermissions,
                [HashTable] $ReplacementHash
            )

            $InvokeCommandParams = @{
                ScriptBlock  = $DryAD_SB_JsonGPO_Import
                ArgumentList = $GPOImportArgumentList
                ErrorAction  = 'Continue'
            }

            if ($PSCmdlet.ParameterSetName -eq 'Remote') {
                $InvokeCommandParams += @{
                    Session = $PSSession
                }
            }
            $GPOImportResult = $Null
            $GPOImportResult = Invoke-Command @InvokeCommandParams

            switch ($GPOImportResult[0]) {
                $true {
                    ol s "$($GPOImportResult[2])"
                }
                default {
                    ol f "$($GPOImportResult[2])"
                    throw $GPOImportResult[1].ToString()
                }
            }
        }
        default {
            throw "Unknown GPO type: $($GPO.Type)"
        }
    }
}
