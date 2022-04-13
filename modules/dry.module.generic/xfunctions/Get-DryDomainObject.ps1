<# 
 This module provides generic functions for use with DryDeploy.

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


function Get-DryDomainObject {
    [cmdletbinding()]
    param ()

    # Create the Object and the function to add to the object in the function scope. 
    $Object = New-Object -TypeName PSObject

    # Get the local site
    $SiteObject = [ActiveDirectorySite]::GetComputerSite()
    $Object | Add-Member -MemberType NoteProperty -Name  "site" -Value $SiteObject.Name

    $Object | Add-Member -MemberType NoteProperty -Name  "sitename" -Value $SiteObject.Name
    
    # Get a Domain Object
    $DNSDomain = [Domain]::GetComputerDomain().Name
    $Object | Add-Member -MemberType NoteProperty -Name "domain" -Value $DNSDomain 

    $Object | Add-Member -MemberType NoteProperty -Name  "domainFQDN" -Value $DNSDomain
    $DNSDomainArr = $DNSDomain.split(".")

    # Get the netBIOS domain name
    $Object | Add-Member -MemberType NoteProperty -Name "domainNB" -Value $DNSDomainArr[0]

    # Find one in local site and set 'LocalDC' to $true. if none was 
    # found in local site, set the 'LocalDC' to $false
    $Context = New-Object DirectoryContext("domain",$DNSDomain)
    $DCObject = [DomainController]::findone($Context,$SiteObject.Name) 
    if ($NULL -eq $DCObject) {
        $DCObject = [DomainController]::findone($Context)
        $Object | Add-Member -MemberType NoteProperty -Name "LocalDC" -Value $False
    } 
    else {
        $Object | Add-Member -MemberType NoteProperty -Name "LocalDC" -Value $True
    }
    $Object | Add-Member -MemberType NoteProperty -Name  "DomainControllerFQDN" -Value $DCObject.Name

    #NetBIOS name. Incorrect, should change it
    $DCarr = $($DCObject.Name).split(".")
    $Object | Add-Member -MemberType NoteProperty -Name  "DomainControllerNB" -Value $DCarr[0]

    $DomainNC = "DC=" + $($DNSDomain.replace(".",",DC="))
    $Object | Add-Member -MemberType NoteProperty -Name  "DomainNC" -Value $DomainNC

    $Object | Add-Member -MemberType NoteProperty -Name  "DomainDN" -Value $DomainNC

    $ConfigurationNC = "CN=Configuration," + $DomainNC 
    $Object | Add-Member -MemberType NoteProperty -Name  "ConfigurationNC" -Value $ConfigurationNC

    $SchemaNC = "CN=Schema,CN=Configuration," + $DomainNC
    $Object | Add-Member -MemberType NoteProperty -Name  "SchemaNC" -Value $SchemaNC

    $ForestDNSZonesNC = "DC=ForestDNSZones," + $DomainNC 
    $Object | Add-Member -MemberType NoteProperty -Name  "ForestDNSZonesNC" -Value $ForestDNSZonesNC

    $DomainDNSZonesNC = "DC=DomainDNSZones," + $DomainNC
    $Object | Add-Member -MemberType NoteProperty -Name  "DomainDNSZonesNC" -Value $DomainDNSZonesNC
    
    return $Object
}