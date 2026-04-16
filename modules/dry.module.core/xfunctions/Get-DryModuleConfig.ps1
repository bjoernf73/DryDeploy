<#
 This module provides core functionality for DryDeploy.


#>

function Get-DryModuleConfig{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ConfigCombo,

        [Parameter(Mandatory,HelpMessage="Object to merge changes into")]
        [PSCustomObject]$Configuration
    )
    try{
        # Mandatory Module Configuration directories
        @($ConfigCombo.moduleconfig.rolespath,$ConfigCombo.moduleconfig.buildpath).Foreach({
            try{
                Test-Path -Path $_ -ErrorAction Stop | Out-Null
            }
            catch{
                throw "Module is missing mandatory directory '$_'"
            }
        })

        $Configuration = Get-DryConfigData -Path $ConfigCombo.moduleconfig.buildpath -Configuration $Configuration

        # Each folder below $ConfigCombo.moduleconfig.rolespath should have a Config.Json containing
        # meta properties for the Roles. Pick up and create a an array RoleMetaConfigs, and add to the configuration.
        $RoleConfigFolders = Get-ChildItem -Path $ConfigCombo.moduleconfig.rolespath -Attributes Directory -ErrorAction Stop
        $COObjects = @()
        $RoleConfigFolders.foreach({
            $COObject = New-Object -TypeName PSObject
            $COObjectJson = Get-DryFromJson -Path (Join-Path -Path $_.FullName -ChildPath 'Config.json')
            $COObjectJson.PSObject.Properties.Foreach({
                $COObject | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value
            })
            $COObjects+=$COObject
        })
        $Configuration | Add-Member -MemberType NoteProperty -Name RoleMetaConfigs -Value $COObjects

        # Credentials
        if(Test-Path -Path $ConfigCombo.moduleconfig.credentialspath){
            $Configuration = Get-DryConfigData -Path $ConfigCombo.moduleconfig.credentialspath -Configuration $Configuration
        }
        return $Configuration
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}