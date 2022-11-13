using Namespace System.Collections.Generic
using Namespace System.Collections

class InteractiveResources {
    [ArrayList] $InteractiveResources

    # create an instance
    InteractiveResources ([PSCustomObject] $Configuration,[PSCustomObject] $ConfigCombo) {

        <#
        Build                 : @{order_type=role; roles=System.Object[]}
        CoreConfig            : @{connections=System.Object[]; network=; resources=System.Object[]}
        ModuleConfigDirectory : C:\GITs\DRY\ModuleConfigs\DomainRoot\
        BaseConfigDirectory     : C:\GITs\DRYCORE\EnvConfigs\utv.local\BaseConfig
        RoleMetaConfigs       : {@{rolename=ADM; role=adm-winclient; base_config=Windows-10; description=Administration Client}, @{rolename=CA; role=ca-certauth-iss; base_config=WindowsServer; description=Windows Server Issuing Root CA}, @{rolename=CA; role=ca-certauth-root;
                                base_config=WindowsServer; description=Windows Server Standalone Root CA}, @{rolename=DC; role=dc-domctrl-add; base_config=WindowsServer; description=Additional DC}...}
        UserConfig            : @{ad.import=; CoreConfig=; credentials=System.Object[]; BaseConfigDirectory=; platforms=System.Object[]; UserConfig=; common_variables=System.Object[]; resource_variables=System.Object[]}
        credentials           : {@{alias=alternate-domain-admin; username=###DomainNB###\bjoernf}, @{alias=domain-admin; username=###DomainNB###\Administrator}}
        CredentialsType       : encryptedstring
        #>
        
        $This.InteractiveResources = [ArrayList]::New()
        
        # Create a loop that interactively builds each resource
        # Write-Host ($Configuration.Build.roles | Select-Object -Property order,role,description | Out-String)
        $iRolesRToSelectFrom = [ArrayList]::New()
        foreach ($iRole in $Configuration.Build.roles) {
            $iIndex = $iRole.order
            $iRoleName = $iRole.role
            $iDescription = $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $iRoleName -Property 'description')
            $iRolesRToSelectFrom+=[PSCustomObject]@{index=$iIndex;role=$iRoleName;description=$iDescription}
        }
        #ol i "er no feil her..."
        foreach ($iString in $($($iRolesRToSelectFrom | Out-String) -split "`n")) {
            ol i "$iString"
        }
        # Loop through the resources in the build
        foreach ($Resource in $Configuration.CoreConfig.resources | Where-Object { $_.role -in @($Configuration.Build.roles.role) }) {
            $Resource = [Resource]::New(
                $Resource.Name,
                $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $Resource.role -Property 'role_short_name'),
                $Resource.Role,
                $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $Resource.role -Property 'base_config'),
                $Configuration.Paths.BaseConfigDirectory,
                $(Get-DryObjectPropertyFromObjectArray -ObjectArray $Configuration.RoleMetaConfigs -IDProperty 'role' -IDPropertyValue $Resource.role -Property 'description'),
                $Resource.Network,
                $ConfigCombo,
                $Configuration,
                $Resource.Options
            )
            #! Previously, this called Replace-Patterns etc
            $This.Resources += $Resource
        }
        $This.DoOrder($Configuration.CoreConfig.Network,$Configuration.Build)
        $This.AddActionGuids()
    }

    [Void] AddActionGuids () {
        $This.Resources.foreach({
            $ResourceOrder = $_.ResourceOrder
            foreach ($Action in $_.ActionOrder) {
                $ActionOrder = $Action.order
                $Action | Add-Member -MemberType NoteProperty -Name 'Action_Guid' -Value ($This.NewActionGuid($ResourceOrder,$ActionOrder))
            }
        })
    } 

    [String] NewActionGuid([int]$ResourceOrder,[int]$ActionOrder) { 
        return [string]('{0:d4}' -f $ResourceOrder) + [string]('{0:d4}' -f $ActionOrder) + '0000-' + ((New-Guid).Guid)
    }



   

    

    [Void] Save ($ResourcesFile,$Archive,$ArchiveFolder) {
        if ($Archive) {
            # Archive previous resources Plan-file and create new
            if (Test-Path -Path $ResourcesFile -ErrorAction SilentlyContinue) {
                ol v "ResourcesFile '$ResourcesFile' exists, archiving" 
                Save-DryArchiveFile -ArchiveFile $ResourcesFile -ArchiveFolder $ArchiveFolder
            }
        }
        
        ol v "Saving resourcesfile '$ResourcesFile'"
        Set-Content -Path $ResourcesFile -Value (ConvertTo-Json -InputObject $This -Depth 100) -Force
    }
}