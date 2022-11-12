# Scriptblock for ScriptMethod to read the ConfigCombo
[scriptblock]$dry_core_sb_configcombo_change = {
    [CmdLetBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$Path,

        [Parameter(Mandatory,
        HelpMessage="Specify it you're modifying the 'environment' or 'module'")]
        [ValidateSet('environment','module')]
        [String]$Type
    )
    try {
        $FullPath = Resolve-DryUtilsFullPath -Path $Path 
        $RootConfigFile = Join-Path -Path $FullPath -ChildPath 'Config.json'
        [PSCustomObject]$RootConfig = Get-DryFromJson -Path $RootConfigFile
        if ($RootConfig.type -ne "$Type") {
            throw "The root config file '$RootConfigFile' is not of type '$Type'"
        }
        else {
            switch ($Type) {
                'environment' {
                    $PropTypeName = 'envconfig'
                }
                'module' {
                    $PropTypeName = 'moduleconfig'
                }
            }
            $this."$PropTypeName".name         = $RootConfig.name
            $this."$PropTypeName".type         = $Type
            $this."$PropTypeName".guid         = $RootConfig.guid 
            $this."$PropTypeName".path         = $FullPath
            $this."$PropTypeName".description  = $RootConfig.description
            $this."$PropTypeName".dependencies = $RootConfig.dependencies."$($this.platform)"."$($this.edition)"
            
            switch ($Type) {
                'environment' {
                    $this.envconfig.coreconfigpath  = (Join-Path -Path $FullPath -ChildPath 'CoreConfig')
                    $this.envconfig.userconfigpath  = (Join-Path -Path $FullPath -ChildPath 'UserConfig')
                    $this.envconfig.BaseConfigPath    = (Join-Path -Path $FullPath -ChildPath 'BaseConfig')
                }
                'module' {
                    $this.moduleconfig.buildpath       = (Join-Path -Path $FullPath -ChildPath 'Build')
                    $this.moduleconfig.rolespath       = (Join-Path -Path $FullPath -ChildPath 'Roles')
                    $this.moduleconfig.credentialspath = (Join-Path -Path $FullPath -ChildPath 'Credentials')
                    if ($null -eq $RootConfig.interactive) {
                        $this.moduleconfig.interactive   = $false
                    }
                    else {
                        $this.moduleconfig.interactive   = $RootConfig.interactive
                    }
                }
            }

            # Save to file
            $this.Save()
        }
    }
    catch {
        throw $_
    }
}