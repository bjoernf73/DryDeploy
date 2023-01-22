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

function ConvertTo-DryADCase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String]$Name,

        [ValidateSet('upper', 'lower', 'ignore', 'capitalized', 'capitalize')]
        [Parameter(Mandatory)]
        [String]$Case 
    )
    if ($Case -eq 'capitalize') {
        $Case = 'capitalized'
    }
    ol d @("Converting '$Name' to type", "$Case") 
   
    function PRIVATE:Capitalize {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [String]$Name
        )
        $Name = $Name.Trim()

        if ($Name.length -le 1) {
            return $Name.ToUppper()
        } 
        elseif ($Name -match ' ') {
            $Parts = $Name.split(' ')
            [String]$AccumulatedParts = ''
            foreach ($Part in $Parts) {
                $UpperCasePart = ($Part.SubString(0, 1)).ToUpper()
                $LowerCasePart = ($Part.Substring(1, ($Part.length - 1))).ToLower()
                $AccumulatedParts += $UpperCasePart + $LowerCasePart + ' '
            }
            return $AccumulatedParts.Trim()
        } 
        else {
            $UpperCasePart = ($Name.SubString(0, 1)).ToUpper()
            $LowerCasePart = ($Name.Substring(1, ($Name.length - 1))).ToLower()
            $ReturnString = $UpperCasePart + $LowerCasePart
            return $ReturnString
        }        
    }
    
    switch ($Case) {
        'ignore' {
            $ReturnValue = $Name
        }
        'upper' {
            $ReturnValue = $Name.ToUpper()
        }
        'lower' {
            $ReturnValue = $Name.ToLower()
        }
        'capitalized' {
            # If distinguishedname, $Name is split into parts. First letter of each part is capitalized
            if (($Name -match "OU=") -or 
                ($Name -match "CN=") -or 
                ($Name -match "DC=")
            ) {
                [String]$AccumulatedStringValue = ''
                $NameParts = @($Name.Split(','))
                foreach ($Part in $NameParts) {
                    # The first three letters are part of 
                    # delimiter, 'OU=', 'CN=' or 'DC='
                    $Delimter = $Part.SubString(0, 3)
                    $Namepart = $Part.SubString(3, ($Part.length - 3))
                    $Namepart = Capitalize -name $NamePart
                    # put into $AccumulatedStringValue
                    $AccumulatedStringValue += ($delimter + $Namepart + ',')
                }
                $ReturnValue = $AccumulatedStringValue.TrimEnd(',')
            } 
            else {
                if ($Name.length -le 1) {
                    $ReturnValue = $Name.ToUpper()
                } 
                else {
                    $ReturnValue = Capitalize -name $Name
                }
            }
        }
    }

    ol d @('Converted to', "$ReturnValue")
    $ReturnValue
}
