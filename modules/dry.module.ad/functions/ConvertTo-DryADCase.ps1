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

Function ConvertTo-DryADCase {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String]$Name,

        [ValidateSet('upper', 'lower', 'ignore', 'capitalized', 'capitalize')]
        [Parameter(Mandatory)]
        [String]$Case 
    )
    If ($Case -eq 'capitalize') {
        $Case = 'capitalized'
    }
    ol d @("Converting '$Name' to type", "$Case") 
   
    Function PRIVATE:Capitalize {
        [CmdletBinding()]
        Param (
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [String]$Name
        )
        $Name = $Name.Trim()

        If ($Name.length -le 1) {
            Return $Name.ToUppper()
        } 
        ElseIf ($Name -match ' ') {
            $Parts = $Name.split(' ')
            [String]$AccumulatedParts = ''
            ForEach ($Part in $Parts) {
                $UpperCasePart = ($Part.SubString(0, 1)).ToUpper()
                $LowerCasePart = ($Part.Substring(1, ($Part.length - 1))).ToLower()
                $AccumulatedParts += $UpperCasePart + $LowerCasePart + ' '
            }
            Return $AccumulatedParts.Trim()
        } 
        Else {
            $UpperCasePart = ($Name.SubString(0, 1)).ToUpper()
            $LowerCasePart = ($Name.Substring(1, ($Name.length - 1))).ToLower()
            $ReturnString = $UpperCasePart + $LowerCasePart
            Return $ReturnString
        }        
    }
    
    Switch ($Case) {
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
            If (($Name -match "OU=") -or 
                ($Name -match "CN=") -or 
                ($Name -match "DC=")
            ) {
                [String]$AccumulatedStringValue = ''
                $NameParts = @($Name.Split(','))
                ForEach ($Part in $NameParts) {
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
            Else {
                If ($Name.length -le 1) {
                    $ReturnValue = $Name.ToUpper()
                } 
                Else {
                    $ReturnValue = Capitalize -name $Name
                }
            }
        }
    }

    ol d @('Converted to', "$ReturnValue")
    $ReturnValue
}
