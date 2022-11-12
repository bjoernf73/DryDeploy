# Scriptblock for ScriptMethod to read the ConfigCombo
[scriptblock]$dry_core_sb_configcombo_read = {
    try {
        [PSCustomObject]$ConfigCombo = Get-DryFromJson -Path $This.Path
        $this.name = $ConfigCombo.name
        $this.path = $ConfigCombo.path

        # EnvConfig -> @{ name = ''; type = 'environment';  guid = ''; path = ''; description = ''; dependencies_hash = ''; dependencies = ''}
        $this.envconfig.path = $ConfigCombo.envconfig.path
        if($null -ne $ConfigCombo.envconfig.path) {
            $EnvConfig = Get-DryFromJson -Path (Join-Path -Path $this.envconfig.path -ChildPath 'Config.json')
            $this.envconfig.name              = $EnvConfig.name
            $this.envconfig.type              = $EnvConfig.type
            $this.envconfig.guid              = $EnvConfig.guid 
            $this.envconfig.description       = $EnvConfig.description 
            $this.envconfig.dependencies      = $EnvConfig.dependencies."$($this.platform)"."$($this.edition)"
            # the dependencies_hash is a calculated property - but we read the value already on file, if any
            $this.envconfig.dependencies_hash = $ConfigCombo.envconfig.dependencies_hash
            $this.envconfig.coreconfigpath    = (Join-Path -Path $this.envconfig.path -ChildPath 'CoreConfig')
            $this.envconfig.userconfigpath    = (Join-Path -Path $this.envconfig.path -ChildPath 'UserConfig')
            $this.envconfig.BaseConfigPath      = (Join-Path -Path $this.envconfig.path -ChildPath 'BaseConfig')
        }

        # ModuleConfig
        $this.moduleconfig.path = $ConfigCombo.moduleconfig.path
        if ($null -ne $ConfigCombo.moduleconfig.path) {
            $Moduleconfig = Get-DryFromJson -Path (Join-Path -Path $this.moduleconfig.path -ChildPath 'Config.json')
            $this.moduleconfig.name              = $Moduleconfig.name
            $this.moduleconfig.type              = $Moduleconfig.type
            $this.moduleconfig.guid              = $Moduleconfig.guid 
            $this.moduleconfig.description       = $Moduleconfig.description 
            $this.moduleconfig.dependencies      = $Moduleconfig.dependencies."$($this.platform)"."$($this.edition)"
            if ($null -eq $Moduleconfig.interactive) {
                $this.moduleconfig.interactive   = $false
            }
            else {
                $this.moduleconfig.interactive   = $Moduleconfig.interactive
            }
            
            # the dependencies_hash is a calculated property - but we read the value already on file, if any
            $this.moduleconfig.dependencies_hash = $ConfigCombo.moduleconfig.dependencies_hash
            $this.moduleconfig.buildpath         = (Join-Path -Path $this.moduleconfig.path -ChildPath 'Build')
            $this.moduleconfig.rolespath         = (Join-Path -Path $this.moduleconfig.path -ChildPath 'Roles')
            $this.moduleconfig.credentialspath   = (Join-Path -Path $this.moduleconfig.path -ChildPath 'Credentials')
        }

        # SystemConfig
        $this.systemconfig.dependencies_hash = $ConfigCombo.systemconfig.dependencies_hash
        $this.Save()
    }
    catch {
        throw $_
    }
}