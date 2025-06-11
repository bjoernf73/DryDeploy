# Scriptblock for ScriptMethod to read the ConfigCombo
[scriptblock]$dry_core_sb_configcombo_change ={
    [CmdLetBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory,
        HelpMessage="Specify it you're modifying the 'environment' or 'module'")]
        [ValidateSet('environment','module')]
        [string]$Type
    )
    try{
        $FullPath = Resolve-DryUtilsFullPath -Path $Path 
        $RootConfigFile = Join-Path -Path $FullPath -ChildPath 'Config.json'
        [PSCustomObject]$RootConfig = Get-DryFromJson -Path $RootConfigFile
        if($RootConfig.type -ne "$Type"){
            throw "The root config file '$RootConfigFile' is not of type '$Type'"
        }
        else{
            switch($Type){
                'environment'{
                    $PropTypeName = 'envconfig'
                }
                'module'{
                    $PropTypeName = 'moduleconfig'
                }
            }
            $this."$PropTypeName".name         = $RootConfig.name
            $this."$PropTypeName".type         = $Type
            $this."$PropTypeName".guid         = $RootConfig.guid 
            $this."$PropTypeName".path         = $FullPath
            $this."$PropTypeName".description  = $RootConfig.description
            $this."$PropTypeName".dependencies = $RootConfig.dependencies."$($this.platform)"."$($this.edition)"
            
            switch($Type){
                'environment'{
                    $this.envconfig.coreconfigpath  = (Join-Path -Path $FullPath -ChildPath 'coreconfig')
                    $this.envconfig.userconfigpath  = (Join-Path -Path $FullPath -ChildPath 'userconfig')
                    $this.envconfig.BaseConfigPath    = (Join-Path -Path $FullPath -ChildPath 'baseconfig')
                }
                'module'{
                    $this.moduleconfig.buildpath       = (Join-Path -Path $FullPath -ChildPath 'build')
                    $this.moduleconfig.rolespath       = (Join-Path -Path $FullPath -ChildPath 'roles')
                    $this.moduleconfig.credentialspath = (Join-Path -Path $FullPath -ChildPath 'credentials')
                }
            }

            # Save to file
            $this.Save()
        }
    }
    catch{
        throw $_
    }
}