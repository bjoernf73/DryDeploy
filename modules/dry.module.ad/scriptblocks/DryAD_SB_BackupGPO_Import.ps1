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

[ScriptBlock] $DryAD_SB_BackupGPO_Import = {
    [CmdletBinding()]
    param (
        [String]
        $BackupName,

        [String]
        $TargetName,

        [String]
        $Path,

        [Hashtable]
        $Replacements,

        [String]
        $Server,

        [Switch]
        $Force
    )    
    try {
        $Status = $False
        $DoImport = $False
        
        [Bool]$GPOExists = $False  # only true if so proven during the calling of ImportGPO()
        [Array]$RemoteMessages = @("Importing Backup-GPO '$BackupName' as target '$TargetName'")

        function Get-RandomHex {
            [CmdletBinding()]   
            param ([int]$Length)
            try {
                $Hex = '0123456789ABCDEF'
                [string]$return = $null
                for ($i = 1; $i -le $Length; $i++) {
                    $return += $Hex.Substring((Get-Random -Minimum 0 -Maximum 16), 1)
                }
                return $Return
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }

        function Get-RandomPath {
            [CmdletBinding()]
            param (
                [Parameter()]
                [String]
                $FolderPath = $ENV:TEMP,
        
                [Parameter()]
                [String]
                $Extension,
        
                [Parameter()]
                [Int]
                $Length = 12
            )
            try {
                $RandomString = Get-RandomHex -Length $Length
                if ($Extension) {
                    return (Join-Path -Path $FolderPath -ChildPath $($RandomString + ".$Extension"))
                } 
                else {
                    return (Join-Path -Path $FolderPath -ChildPath $RandomString)
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            
        }

        try {
            Get-GPO -Name $TargetName -Server $Server -ErrorAction Stop | Out-Null
            $GPOExists = $True
            $RemoteMessages += "Target Backup-GPO '$TargetName' exists already"
            if ($Force) {
                $RenamedGPO = "$($TargetName)-OLD-$((Get-Date -Format s).Replace(':','-'))" 
                $GPO = Get-GPO -Name $TargetName -Server $Server -ErrorAction 'Stop'
                Rename-GPO -Guid $GPO.ID -TargetName $RenamedGPO  -Server $Server -ErrorAction 'Stop' | Out-Null
                # Set this to $False so it will be imported later
                $GPOExists = $False
                $DoImport = $True
            } 
            else {
                $RemoteMessages += "-Force not passed, so I will do nothing"
                $Status = $True
                $DoImport = $False
            }
            
        } 
        catch { 
            if ("$($_.ToString())" -match "GPO was not found") {
                $GPOExists = $False
                $DoImport = $True
                $RemoteMessages += "Target Backup-GPO '$TargetName' does not exist - importing it."
            } 
            else {
                $RemoteMessages += "Unexpected error running Get-GPO -Name '$TargetName' "
                $RemoteMessages += "Error: $($_.ToString()) "
                $DoImport = $False
                # Some other error record - throw a terminating error
                $Status = $False
                # $PSCmdlet.ThrowTerminatingError($_)
            } 
        } 

        if (
            ($GPOExists -eq $False) -and 
            ($DoImport -eq $True)
        ) { 
            $ImportGPOParams = @{          
                BackupGpoName  = $BackupName
                TargetName     = $TargetName
                Server         = $Server
                CreateIfNeeded = $True
                Path           = $Path
                ErrorAction    = 'Stop'
            }
            $MigTablePath = Join-Path -Path $Path -ChildPath ($BackupName + '.migtable')
            $RemoteMessages += "If migtable exists, it's path should be '$MigTablePath'"
            $TempMigTable = $Null
            if (Test-Path -Path $MigTablePath) {
                $RemoteMessages += "The migtable '$MigTablePath' exists!"
                $TempMigTable = Get-RandomPath -extension 'migtable'
                $RemoteMessages += "Creating temporary migtable clone '$TempMigTable'"

                $MigTableContent = Get-Content -Path $MigTablePath -Raw -ErrorAction Stop
                foreach ($Key in $Replacements.Keys) {
                    $MigTableContent = $MigTableContent -replace $Key, $Replacements["$Key"]  
                }
                $MigTableContent | Out-File -FilePath $TempMigTable -Encoding unicode -Force -ErrorAction Stop
                $ImportGPOParams += @{
                    'MigrationTable' =$TempMigTable 
                }
            } 
            else {
                $RemoteMessages += "The migtable was not found, assuming no values to migrate"
            }
                   
            try {
                Import-GPO @ImportGPOParams | Out-Null
                $Status = $True
                $RemoteMessages += "Success importing GPO '$TargetName'"
            } 
            catch {
                $RemoteMessages += "Error importing GPO '$TargetName' using migtable '$TempMigTable'"
                Start-Sleep -Seconds 2
                # If import fails, the GPO may have been created as an  
                # empty or partly configured object, if so, remove it
                $GetGPOParams = @{
                    Name        = "$TargetName"
                    Server      = $Server
                    ErrorAction = 'Ignore'
                }
                $RemoveGPOParams = @{
                    Confirm     = $False
                    ErrorAction = 'Ignore'
                }
                Get-GPO @GetGPOParams | Remove-GPO @RemoveGPOParams | Out-Null
                throw $_
            }
            finally {
                if ($TempMigTable) {
                    Remove-Item -Path $TempMigTable -Confirm:$False -Force -ErrorAction Ignore | Out-Null
                }
            }
        }
        @($Status, $Null, $RemoteMessages)
    }
    catch {
        @($Status, $_, $RemoteMessages)
    }
    finally {
    }  
}

