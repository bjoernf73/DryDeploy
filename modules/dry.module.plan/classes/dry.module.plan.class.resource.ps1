using Namespace System.Collections.Generic
using Namespace System.Collections
class Resource {
    [string]$Name
    [string]$Role 
    [string]$Role_Short_Name
    [string]$BaseConfig
    [string]$Description
    [int]$ResourceOrder
    [string]$BaseConfigPath
    [string]$RolePath
    [string]$ConfigurationTargetPath
    [Guid]$Resource_Guid
    [PSCustomObject]$Network
    [Network]$Resolved_Network
    [PSCustomObject]$ActionOrder
    [PSCustomObject]$Options

    # Initial creation of the resource
    Resource (
        [string]$Name,
        [string]$role_short_name,
        [string]$Role,
        [string]$BaseConfig,
        [string]$BaseConfigPath,
        [string]$Description,
        [PSCustomObject]$Network,
        [PSCustomObject]$ConfigCombo,
        [PSCustomObject]$Configuration,
        [PSCustomObject]$Options
    ) {
        $This.Name                     = $Name
        $This.role_short_name          = $role_short_name
        $This.Role                     = $Role
        $This.BaseConfig               = $BaseConfig
        $This.BaseConfigPath           = Join-Path -Path $BaseConfigPath -ChildPath $BaseConfig -Resolve
        $This.Description              = $Description
        $This.ResourceOrder            = 0
        $This.Network                  = $Network
        $This.Resolved_Network         = [Network]::New($Network,$Configuration.CoreConfig.network.sites)
        $This.RolePath                 = Join-Path -Path $ConfigCombo.moduleconfig.rolespath -ChildPath $Role -Resolve
        $This.ConfigurationTargetPath  = Join-Path -Path ($Configuration.Paths.TempConfigsDir) -ChildPath $This.Name
        $This.Resource_Guid            = $($(New-Guid).Guid)
        $This.Options                  = $Options

        Remove-Variable -Name BuildTemplate -ErrorAction Ignore
        $BuildTemplate = $Configuration.build.roles | Where-Object {
            $_.role -eq $Role
        }
        if ($null -eq $BuildTemplate) {
            throw "The Build does not contain a Role '$($This.Role)'"
        }
        elseif ($BuildTemplate -is [array]) {
            throw "The Build contains multiple Roles matching '$($This.Role)'"
        }
        # Get a copy of the Build Object. The Build is now instantiated by a Resource, 
        # but there may be many Resources in the Plan using that Tempolate. So, not to contaminate 
        # the Template with the unique GUID of each Action, use a copy
        $ResourceBuild = Get-DryUtilsPSObjectCopy -Object $BuildTemplate
        $ResourceBuild.actions.foreach({
            $_ | Add-Member -MemberType NoteProperty -Name 'Role' -Value $Role
        })
        $This.ActionOrder = $ResourceBuild.actions
    }
}