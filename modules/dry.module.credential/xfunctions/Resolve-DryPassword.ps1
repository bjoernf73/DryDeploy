<#
 This module handles credentials for DryDeploy

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.credential/main/LICENSE
#>

function Resolve-DryPassword{
    [CmdletBinding()]
    param(
        [Parameter(ParametersetName="InputObject",Mandatory,HelpMessage="Expects an object in which one or more property (or nested property) value matches the replacement string '___pwd___*___'")]
        [PSCustomObject]$InputObject,

        [ValidatePattern("___pwd___.*___")]
        [Parameter(ParametersetName="InputString",Mandatory,HelpMessage="Expects a string matching one of the replacement strings")]
        [string]$InputString
    )
    
    try{
        if($InputObject){
            # make a copy of the object, or else the changes 
            # may be written back to the original object
            $CopyObject = $InputObject.PSObject.Copy()
            $CopyObject.PSObject.Properties | 
                Foreach-Object{
                $PropertyName = $_.Name
                $PropertyValue = $_.Value
                # If Key is a string, we can do the replacement. If it is an
                # object, we must make a nested call. If array, make nested
                # call for each element of the array
                if(($PropertyValue -is [string])-and ($PropertyValue -match "___pwd___.*___")){
                    # Call Resolve-DryPassword that returns the replaced string
                    $PropertyValue = Resolve-DryPassword -InputString $PropertyValue
                }
                elseif($PropertyValue -is [PSObject]){
                    # make a nested call to this function
                    $PropertyValue = Resolve-DryPassword -InputObject $PropertyValue
                } 
                elseif($PropertyValue -is [array]){
                    # nested call for each array element
                    $PropertyValue = @(  $PropertyValue | Foreach-Object{ 
                        if(($_ -is [string]) -and ($_ -match "___pwd___.*___")){
                            Resolve-DryPassword -InputText $_ 
                        } 
                        elseif(($_ -is [string]) -and ($_ -notmatch "___pwd___.*___")){
                            # just return the original object - there is nothing to do
                            $_
                        }
                        else{
                            Resolve-DryPassword -InputObject $_ 
                        }
                    })
                }
                $CopyObject."$PropertyName" = $PropertyValue
            }
            return $CopyObject
        } 
        else{
            # Get the credential alias which is <alias> in '___pwd___<alias>___'
            $CredentialName = $InputString.Substring(9,($InputString.length-12))
            ol v "The credential alias is '$CredentialName'"
            $CredObject = Get-DryCredential -Alias $CredentialName -EnvConfig $GLOBAL:dry_var_global_ConfigCombo.envconfig.name
            $CredObject.GetNetworkCredential().Password
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}