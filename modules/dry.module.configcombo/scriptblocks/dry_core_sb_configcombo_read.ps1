# Scriptblock for ScriptMethod to read the ConfigCombo
[scriptblock]$dry_core_sb_configcombo_read ={
    param(
        $NewEnvConfig,
        $NewModuleConfig
    )
    try{
        [PSCustomObject]$ConfigCombo = Get-DryFromJson -Path $This.Path
        $this.name = $ConfigCombo.name
        $this.path = $ConfigCombo.path

        # EnvConfig 
        if(-not ($NewEnvConfig)){
            $this.envconfig.path = $ConfigCombo.envconfig.path
            if($null -ne $ConfigCombo.envconfig.path){
                $EnvConfig = Get-DryFromJson -Path (Join-Path -Path $this.envconfig.path -ChildPath 'Config.json')
                $this.envconfig.name              = $EnvConfig.name
                $this.envconfig.type              = $EnvConfig.type
                $this.envconfig.guid              = $EnvConfig.guid 
                $this.envconfig.description       = $EnvConfig.description 
                $this.envconfig.dependencies      = $EnvConfig.dependencies."$($this.platform)"."$($this.edition)"
                # the dependencies_hash is a calculated property - but we read the value already on file, if any
                $this.envconfig.dependencies_hash = $ConfigCombo.envconfig.dependencies_hash
                $this.envconfig.coreconfigpath    = (Join-Path -Path $this.envconfig.path -ChildPath 'coreconfig')
                $this.envconfig.userconfigpath    = (Join-Path -Path $this.envconfig.path -ChildPath 'userconfig')
                $this.envconfig.BaseConfigPath      = (Join-Path -Path $this.envconfig.path -ChildPath 'baseconfig')
            }
        }
        
        # ModuleConfig
        if(-not ($NewModuleConfig)){
            $this.moduleconfig.path = $ConfigCombo.moduleconfig.path
            if($null -ne $ConfigCombo.moduleconfig.path){
                $Moduleconfig = Get-DryFromJson -Path (Join-Path -Path $this.moduleconfig.path -ChildPath 'Config.json')
                $this.moduleconfig.name              = $Moduleconfig.name
                $this.moduleconfig.type              = $Moduleconfig.type
                $this.moduleconfig.guid              = $Moduleconfig.guid 
                $this.moduleconfig.description       = $Moduleconfig.description 
                $this.moduleconfig.dependencies      = $Moduleconfig.dependencies."$($this.platform)"."$($this.edition)"
                
                # the dependencies_hash is a calculated property - but we read the value already on file, if any
                $this.moduleconfig.dependencies_hash = $ConfigCombo.moduleconfig.dependencies_hash
                $this.moduleconfig.buildpath         = (Join-Path -Path $this.moduleconfig.path -ChildPath 'build')
                $this.moduleconfig.rolespath         = (Join-Path -Path $this.moduleconfig.path -ChildPath 'roles')
                $this.moduleconfig.credentialspath   = (Join-Path -Path $this.moduleconfig.path -ChildPath 'credentials')
            }
        }

        # SystemConfig
        $this.systemconfig.dependencies_hash = $ConfigCombo.systemconfig.dependencies_hash
        $this.Save()
    }
    catch{
        throw $_
    }
}