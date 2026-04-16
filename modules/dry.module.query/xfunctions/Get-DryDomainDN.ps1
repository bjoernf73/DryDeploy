# This module is an action module for use with DryDeploy. It runs a DSC
# Config on a target
# Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
# LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.action.dsc.run/main/LICENSE
#


function Get-DryDomainDN{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Configuration,

        [Parameter()]
        [switch]$SchemaDN,

        [Parameter()]
        [switch]$ConfigurationDN
    )
    try{
        $DomainFQDN = $Configuration.CoreConfig.network.domain.domain_fqdn
        $DomainDN = ConvertTo-DryUtilsDomainDN -DomainFQDN $DomainFQDN
        if($ConfigurationDN -or $SchemaDN){
            $DomainDN = "CN=Configuration,$DomainDN"
        }
        if($SchemaDN){
            $DomainDN = "CN=Schema,$DomainDN"
        }
        $DomainDN
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}