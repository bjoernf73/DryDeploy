using Namespace System.Collections.Generic
using Namespace System.Collections
class Resource {
    [String]          $Name
    [String]          $Role 
    [String]          $Role_Short_Name
    [String]          $OS_Tag
    [String]          $Description
    [Int]             $ResourceOrder
    [String]          $OSConfigPath
    [String]          $RolePath
    [String]          $ConfigurationTargetPath
    [Guid]            $Resource_Guid
    [PSCustomObject]  $Network
    [Network]         $Resolved_Network
    [PSCustomObject]  $ActionOrder
    [PSCustomObject]  $Options

    # Initial creation of the resource
    Resource (
        [String]          $Name,
        [String]          $role_short_name,
        [String]          $Role,
        [String]          $OS_Tag,
        [String]          $OSConfigPath,
        [String]          $Description,
        [PSCustomObject]  $Network,
        [PSCustomObject]  $ConfigCombo,
        [PSCustomObject]  $Configuration,
        [PSCustomObject]  $Options
    ) {
        $This.Name                     = $Name
        $This.role_short_name          = $role_short_name
        $This.Role                     = $Role
        $This.OS_Tag                   = $OS_Tag
        $This.OSConfigPath             = Join-Path -Path $OSConfigPath -ChildPath $OS_Tag -Resolve
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
        if ($Null -eq $BuildTemplate) {
            throw "The Build does not contain a Role '$($This.Role)'"
        }
        elseif ($BuildTemplate -is [Array]) {
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