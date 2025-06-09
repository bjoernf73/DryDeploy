# This module is an action module for use with DryDeploy. It runs a DSC 
# Config on a target
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.dsc.run/main/LICENSE
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

function Get-DryDomainDN{
    [CmdletBinding()]  
    param(
        [Parameter(Mandatory)]
        [psobject]$Configuration,

        [Parameter()]
        [switch]$SchemaDN, 

        [Parameter()]
        [switch]$ConfigurationDN
    )
    try{
        $DomainFQDN = $Configuration.CoreConfig.network.domain.domain_fqdn
        $DomainDN = ConvertTo-DryUtilsDomainDN -DomainFQDN $DomainFQDN
        if($ConfigurationDN -or $SchemaDN){
            $DomainDN = "CN=Configuration,$DomainDN"
        }
        if($SchemaDN){
            $DomainDN = "CN=Schema,$DomainDN"
        }
        $DomainDN
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}