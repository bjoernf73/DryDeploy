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

<# 
.Synopsis 
    Translates a path 'Servers/Serverroles/CA' (from root to leaf) to a 
    domainDN like OU=CA,OU=ServerRoles,OU=Servers (from leaf to root). 
#> 
Function ConvertTo-DryADDistinguishedName {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String]$Name,

        [Parameter()]
        [ValidateSet("upper", "lower", "ignore", "capitalize", "capitalized")]
        [String]$Case = 'ignore'
    )
    
    # chop off any leading or trailing slashes and spaces. 
    $Name = $Name.Trim()
    $Name = $Name.Trim('/')
    ol d @('Input', $Name)   
   
    try {
        [String]$ConvertedName = ""
        
        If (
            ($Name -match "^ou=") -or 
            ($Name -match "^cn=")
        ) {
            # the name is alerady a dN
            ol d @('The input is already a DistinguishedName', $Name)   
            $ConvertedName = "$Name"
        }
        ElseIf ($name -eq '') {
            ol d 'Empty string (probably root of domain - return empty string then'
            $ConvertedName = $name
        }
        Else {
            # names like root/middle/leaf will be converted 
            # to ou=leaf,ou=middle,ou=root. Must assume that 
            # these are OUs, not CNs (or DCs)
            $NameArr = @($Name -split "/")
            For ($c = ($nameArr.Count - 1); $c -ge 0; $c--) {  
                $ConvertedName += "OU=$($nameArr[$c]),"
            }
            # The accumulated name ends with ',', chop that off
            $ConvertedName = $ConvertedName.TrimEnd(',')
        }

        ol d @('Sending to ConvertTo-DryADCase' , "$ConvertedName")
        $ConvertedName = ConvertTo-DryADCase -Name $ConvertedName -Case $Case 

        ol d @('Returning', "$ConvertedName")  
        $ConvertedName
    }
    Catch {
        ol w "Error converting '$Name' to distinguishedName"  
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
