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


<# 
.Synopsis 
    Translates a path 'Servers/Serverroles/CA' (from root to leaf) to a 
    domainDN like OU=CA,OU=ServerRoles,OU=Servers (from leaf to root). 
#> 
function ConvertTo-DryUtilsDistinguishedName{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter()]
        [ValidateSet("upper", "lower", "ignore", "capitalize", "capitalized")]
        [string]$Case = 'ignore'
    )
    
    # chop off any leading or trailing slashes and spaces. 
    $Name = $Name.Trim()
    $Name = $Name.Trim('/')
    ol d @('Input', $Name)   
   
    try{
        [string]$ConvertedName = ""
        if(
            ($Name -match "^ou=") -or 
            ($Name -match "^cn=")
        ){
            # the name is alerady a dN
            $ConvertedName = "$Name"
        }
        elseif($name -eq ''){
            # Empty string (root of domain - return empty string)
            $ConvertedName = $name
        }
        else{
            # names like root/middle/leaf will be converted 
            # to ou=leaf,ou=middle,ou=root. Must assume that 
            # these are OUs, not CNs (or DCs)
            $NameArr = @($Name -split "/")
            for ($c = ($nameArr.Count - 1); $c -ge 0; $c--){  
                $ConvertedName += "OU=$($nameArr[$c]),"
            }
            $ConvertedName = $ConvertedName.TrimEnd(',')
        }

        ol d @('Sending to ConvertTo-DryUtilsCase' , "$ConvertedName")
        $ConvertedName = ConvertTo-DryUtilsCase -Name $ConvertedName -Case $Case 

        ol d @('Returning', "$ConvertedName")  
        $ConvertedName
    }
    catch{
        ol w "Error converting '$Name' to distinguishedName"  
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
