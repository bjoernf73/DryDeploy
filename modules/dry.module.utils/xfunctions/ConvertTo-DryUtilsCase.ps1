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


function ConvertTo-DryUtilsCase {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String]$Name,

        [ValidateSet('upper','lower','ignore','capitalized','capitalize')]
        [Parameter(Mandatory)]
        [String]$Case 
    )
    if ($Case -eq 'capitalize') { $Case = 'capitalized' }
   
    function PRIVATE:Capitalize-String {
        [CmdLetBinding()]
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
                $UpperCasePart = ($Part.SubString(0,1)).ToUpper()
                $LowerCasePart = ($Part.Substring(1,($Part.length-1))).ToLower()
                $AccumulatedParts += $UpperCasePart + $LowerCasePart + ' '
            }
            return $AccumulatedParts.Trim()
        } 
        else {
            $UpperCasePart = ($Name.SubString(0,1)).ToUpper()
            $LowerCasePart = ($Name.Substring(1,($Name.length-1))).ToLower()
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
            # If dN, split, and capitalize each part
            if (($Name -match "OU=") -or ($Name -match "CN=") -or ($Name -match "DC=")) {
                [String]$AccumulatedStringValue = ''
                $NameParts = @($Name.Split(','))
                foreach ($Part in $NameParts) {
                    $Delimter = $Part.SubString(0,3)
                    $Namepart = $Part.SubString(3,($Part.length-3))
                    $Namepart = Capitalize-String -Name $NamePart
                    $AccumulatedStringValue += ($delimter + $Namepart + ',')
                }
                $ReturnValue = $AccumulatedStringValue.TrimEnd(',')
            } 
            else {
                $ReturnValue = Capitalize-String -Name $Name
            }
        }
    }
    $ReturnValue
}