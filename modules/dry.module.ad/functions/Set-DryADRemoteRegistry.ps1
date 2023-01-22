Using Namespace System.Management.Automation.Runspaces
Using Namespace Microsoft.Win32
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

function Set-DryADRemoteRegistry {
    [CmdletBinding()] 
    param (
        [Parameter()]
        [ValidateSet('HKEY_CLASSES_ROOT', 'HKEY_CURRENT_USER', 'HKEY_LOCAL_MACHINE', 'HKEY_USERS', 'HKEY_CURRENT_CONFIG', 'HKEY_DYN_DATA')]
        [String]$BaseKey = 'HKEY_LOCAL_MACHINE',

        [Parameter(Mandatory)]
        [String]$LeafKey,

        [Parameter(Mandatory)]
        [String]$ValueName,

        [Parameter(Mandatory)]
        $ValueData,

        [Parameter(Mandatory)]
        [ValidateSet('Binary', 'Dword', 'ExpandString', 'MultiString', 'QWord', 'String')]
        [RegistryValueKind]$ValueType,
        
        [Parameter(HelpMessage = "PSSession to the target system")]
        [PSSession]$PSSession
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
        $LeafKey = $LeafKey.Replace('\\', '\')
      
        switch ($ValueType) {
            'Binary' {
                # System.Management.ManagementBaseObject GetBinaryValue(System.UInt32 hDefKey, System.String sSubKeyName, System.String sValueName)
                ol e "Value Type 'Binary' is not implemented"
                $CurrentValue = $Class.GetBinaryValue($BaseKeyInt, $LeafKey, $ValueName)
            }
            'Dword' {
                [ScriptBlock]$DwordScriptBlock = {
                    param (
                        [Uint32] $BaseKeyInt,
                        [String] $LeafKey,
                        [String] $ValueName,
                        [Uint32] $ValueData
                    )

                    $Result = @($False, $Null)
                    try {     
                        $InvokeCimMethodParams = @{
                            'Namespace'   = 'root\cimv2' 
                            'ClassName'   = 'StdRegProv' 
                            'MethodName'  = 'SetDWORDvalue' 
                            'Arguments'   = @{hDefKey = $BaseKeyInt; sSubKeyName = $LeafKey; sValueName = $ValueName; uValue = $ValueData }
                            'ErrorAction' = 'Stop'
                        }
                        Invoke-CimMethod @InvokeCimMethodParams | Out-Null
                        $Result[0] = $True
                    } 
                    catch {
                        $Result[1] = $_
                    }  
                    finally {
                        $Result
                    }
                }

                $InvokeCommandParams = @{
                    'ScriptBlock'  = $DwordScriptBlock
                    'ArgumentList' = @($BaseKeyInt, $LeafKey, $ValueName, $ValueData)
                }

                if ($PSSession) {
                    $InvokeCommandParams += @{
                        'Session' = $PSSession
                    }
                }
                $Result = Invoke-Command @InvokeCommandParams    
            }
            'ExpandString' {
                # System.Management.ManagementBaseObject GetExpandedStringValue(System.UInt32 hDefKey, System.String sSubKeyName, System.String sValueName)
                ol e "Value Type 'ExpandString' is not implemented"
                $CurrentValue = $Class.GetExpandedStringValue($BaseKeyInt, $LeafKey, $ValueName)
            }
            'MultiString' {
                # System.Management.ManagementBaseObject GetMultiStringValue(System.UInt32 hDefKey, System.StringsSubKeyName, System.String sValueName)
                ol e "Value Type 'MultiString' is not implemented"
                $CurrentValue = $Class.GetMultiStringValue($BaseKeyInt, $LeafKey, $ValueName)
            } 
            'QWord' {
                ol e "Value Type 'Qword' is not implemented"
                $CurrentValue = $Class.GetQWordValue($BaseKeyInt, $LeafKey, $ValueName)
            } 
            'String' {
                # System.Management.ManagementBaseObject GetStringValue(System.UInt32 hDefKey, System.String sSubKeyName, System.String sValueName)
                ol e "Value Type 'String' is not implemented"
                $CurrentValue = $Class.GetStringValue($BaseKeyInt, $LeafKey, $ValueName)
            }
        }

        switch ($Result[0]) {
            $True {
                ol v "Successfully configured remote registry"
            }
            $False {
                ol e "Failed to configure remote registry"
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
