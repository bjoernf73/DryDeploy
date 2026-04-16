<#
 This module is a string-pattern-in-object-propety-values replacement module
 for use with DryDeploy

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.pattern.replace/main/LICENSE
#>

function Resolve-DryReplacementPatterns{
    [CmdletBinding()]
    param(
        [Parameter(ParametersetName="InputObject",Position=0,Mandatory)]
        [PSCustomObject]$InputObject,

        [Parameter(ParametersetName="InputText",Position=0,Mandatory)]
        [AllowEmptyString()]
        [string]$InputText,

        [Parameter(ParametersetName="InputObject",Position=1,Mandatory)]
        [Parameter(ParametersetName="InputText",Position=1,Mandatory)]
        [System.Collections.Generic.List[PSObject]]$Variables
    )

    try{
        if(($InputObject -is [array]) -and $InputObject.count -eq 0){
            return
        }
        elseif($InputObject){
            if($InputObject -is [array]){
                # make a copy of the object, so changes don't infect the original
                [array]$CopyObject = $InputObject.PSObject.Copy()
                $ResultArray = @()
                foreach($arrItem in $CopyObject){
                    $ResultArray+= Resolve-DryReplacementPatterns -InputObject $arrItem -Variables $Variables
                }
                $ResultArray
            }
            else{
                # make a copy of the object, so changes don't infect the original
                $CopyObject = $InputObject.PSObject.Copy()
                $CopyObject.PSObject.Properties | Foreach-Object{
                    $PropertyName  = $_.Name
                    $PropertyValue = $_.Value
                    if(($PropertyName -match "common_variables$") -or ($PropertyName -match "resource_variables$")){
                        # the common_variables and resource_variables define the strings to replace, so
                        # avoid replacing them, return the original object
                    }
                    elseif($PropertyValue -is [string]){
                        # if name is a string, we can replace
                        $PropertyValue = Resolve-DryReplacementPattern -InputText $PropertyValue -Variables $Variables
                    }
                    elseif($PropertyValue -is [array]){
                        # nested call for each element in array
                        $PropertyValue = @($PropertyValue | Foreach-Object{
                            if($_ -is [string]){
                                Resolve-DryReplacementPatterns -InputText $_ -Variables $Variables
                            }
                            else{
                                Resolve-DryReplacementPatterns -InputObject $_ -Variables $Variables
                            }
                        })
                    }
                    elseif($PropertyValue -is [PSObject]){
                        # nested call
                        $PropertyValue = Resolve-DryReplacementPatterns -InputObject $PropertyValue -Variables $Variables
                    }
                    $CopyObject."$PropertyName" = $PropertyValue
                }
                return $CopyObject
            }
        }
        else{
            Resolve-DryReplacementPattern -InputText $InputText -Variables $Variables
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}