<#
 This module provides query functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.query/main/LICENSE
#>

<#
.SYNOPSIS
Gets a DC, returning it's short name, DomainFQDN, or IP

.DESCRIPTION
Queries the Configuration, and test's available DC's, preferring the
closest one. Test's which DC is responding, returning that. You may
specify the format you want returned, whether it's the short name,
full FQDN ir IP.

.PARAMETER Configuration
The full $Configuration

.EXAMPLE
Get-DryDC -Configuration $Configuration -Resource $Resource
Return's IP of the DC at the $Resource's site, if there is
one and it's pingable

.EXAMPLE
\n
$Params = @{
'Configuration'=$Configuration;
'Resource'=$Resource
}
Get-DryDC @params -DomainFQDN -NoPing

Return's DomainFQDN of the DC at the $Resource's site, if there
is one, even though it's down (unpingable)
#>
function Get-DryDC{
    [CmdLetBinding(DefaultParameterSetName='IP')]
    param(
        [Parameter(Mandatory,ParameterSetName='DomainFQDN',
        HelpMessage='Returnes FQDN of the DC')]
        [Switch]$DomainFQDN,

        [Parameter(Mandatory,ParameterSetName='ShortName',
        HelpMessage='Returnes short name of the DC')]
        [Switch]$ShortName,

        [Parameter(HelpMessage="Don't require response to
        ping -  just gimme it")]
        [Switch]$NoPing,

        [Parameter(Mandatory)]
        [PSObject]$Configuration,

        [Parameter(Mandatory)]
        [PSObject]$Resource
    )

    try{
        $Role = $Configuration.RoleMetaConfigs | Where-Object{
            $_.Role -eq "$Role"
        }
        if($Role."$Property"){
            return $Role."$Property"
        }
        else{
            throw "The property $Property does not exist on Role $Role"
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}