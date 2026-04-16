<#
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
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
