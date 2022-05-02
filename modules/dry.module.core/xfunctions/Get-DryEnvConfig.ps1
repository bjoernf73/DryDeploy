<# 
 This module provides core functionality for DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.core/main/LICENSE
 
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

function Get-DryEnvConfig {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$ConfigCombo
    )
    try {
        #   The EnvConfig describes the environment into which you deploy your module. 
        #   The EnvConfig is a directory or repository containing two directories; 
        #   
        #   1. 'Config' which contain common environment specific definitions      
        #   2. 'OSConfig' which contains os-specific definitions shared 
        #       among environments 
        $Configuration = $null
        $Configuration = Get-DryConfigData -Path (Join-Path -Path $ConfigCombo.envconfig.path -ChildPath 'Config') -ErrorAction Stop
        
        # Add the resolved OS Configuration directory to the Configuration so that functions
        # below may use that instead of having to resolve relative paths over and over
        $Configuration | Add-Member -MemberType NoteProperty -name OSConfigDirectory -value (Join-Path -Path $ConfigCombo.envconfig.path -ChildPath 'OSConfig')
        return $Configuration
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}