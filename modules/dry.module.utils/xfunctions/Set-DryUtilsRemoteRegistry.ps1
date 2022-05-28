<# 
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
 
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

function Set-DryUtilsRemoteRegistry {
    [CmdletBinding()] 
    param (
        [Parameter()]
        [ValidateSet('LocalMachine','HKEY_CLASSES_ROOT','HKEY_CURRENT_USER','HKEY_LOCAL_MACHINE','HKEY_USERS','HKEY_CURRENT_CONFIG','HKEY_DYN_DATA')]
        [String]$BaseKey = 'LocalMachine',

        [Parameter(Mandatory)]
        [String]$LeafKey,

        [Parameter(Mandatory)]
        [String]$ValueName,

        [Parameter(Mandatory)]
        $ValueData,

        [Parameter(Mandatory)]
        [ValidateSet('Binary','Dword','ExpandString','MultiString','QWord','String')]
        [Microsoft.Win32.RegistryValueKind]$ValueType,
        
        [Parameter(HelpMessage="PSSession to the target system")]
        [System.Management.Automation.Runspaces.PSSession]$PSSession
    )
    try {
    
        switch ($BaseKey) {
            'HKEY_CLASSES_ROOT' { 
                [uint32]$BaseKeyInt = 2147483648 
            }
            'HKEY_CURRENT_USER' { 
                [uint32]$BaseKeyInt = 2147483649 
            }
            'HKEY_LOCAL_MACHINE' { 
                [uint32]$BaseKeyInt = 2147483650 
            }
            'HKEY_USERS' { 
                [uint32]$BaseKeyInt = 2147483651 
            }
            'HKEY_CURRENT_CONFIG' { 
                [uint32]$BaseKeyInt = 2147483653 
            }
            'HKEY_DYN_DATA' { 
                [uint32]$BaseKeyInt = 2147483654 
            }
            default { 
                throw "Unknown BaseKey: $BaseKey"
            }
        }
        $LeafKey = $LeafKey.Replace('\\','\')
        ol d -m "LeafKey is now '$Leafkey'"

        switch ($ValueType) {
            'Binary' {
                # System.Management.ManagementBaseObject GetBinaryValue(System.UInt32 hDefKey, System.String sSubKeyName, System.String sValueName)
                ol w "'Binary' is untested!"
                $CurrentValue = $Class.GetBinaryValue($BaseKeyInt,$LeafKey,$ValueName)
            }
            'Dword' {
                [ScriptBlock]$ScriptBlock = {
                    param (
                        [Uint32] $BaseKeyInt,
                        [String] $LeafKey,
                        [String] $ValueName,
                        [Uint32] $ValueData
                    )

                    $Result = @($False,$Null)
                    try {     
                        $InvokeCimMethodParams = @{
                            'Namespace'='root\cimv2' 
                            'ClassName'='StdRegProv' 
                            'MethodName'='SetDWORDvalue' 
                            'Arguments'=@{hDefKey=$BaseKeyInt; sSubKeyName=$LeafKey; sValueName=$ValueName; uValue=$ValueData }
                            'ErrorAction'='Stop'
                        }
                        Invoke-CimMethod @InvokeCimMethodParams | Out-Null
                        $Result[0] = $True
                    } 
                    catch {
                        $Result[1]=$_
                    }  
                    finally {
                        $Result
                    }
                }

                $InvokeCommandParams = @{
                    'ScriptBlock'=$ScriptBlock
                    'ArgumentList'=@($BaseKeyInt,$LeafKey,$ValueName,$ValueData)
                }

                if ($PSSession) {
                    $InvokeCommandParams+=@{
                        'Session'=$PSSession
                    }
                }
                $Result = Invoke-Command @InvokeCommandParams  
                
            }
            'ExpandString' {
                # System.Management.ManagementBaseObject GetExpandedStringValue(System.UInt32 hDefKey, System.String sSubKeyName, System.String sValueName)
                ol w "'ExpandString' is untested!"
                $CurrentValue = $Class.GetExpandedStringValue($BaseKeyInt,$LeafKey,$ValueName)
            }
            'MultiString' {
                # System.Management.ManagementBaseObject GetMultiStringValue(System.UInt32 hDefKey, System.StringsSubKeyName, System.String sValueName)
                ol w "'MultiString' is untested!"
                $CurrentValue = $Class.GetMultiStringValue($BaseKeyInt,$LeafKey,$ValueName)
            } 
            'QWord' {
                ol w "'Qword' is untested!"
                $CurrentValue = $Class.GetQWordValue($BaseKeyInt,$LeafKey,$ValueName)
            } 
            'String' {
                # System.Management.ManagementBaseObject GetStringValue(System.UInt32 hDefKey, System.String sSubKeyName, System.String sValueName)
                ol w "'String' is untested!"
                $CurrentValue = $Class.GetStringValue($BaseKeyInt,$LeafKey,$ValueName)
            }
        }

        switch ($Result[0]) {
            $True {
                ol i "Successfully configured remote registry"
            }
            $False {
                ol w "Failed to configure remote registry"
                throw $Result[1]
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        
    } 
}