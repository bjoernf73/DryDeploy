# Scriptblock for ScriptMethod to read the ConfigCombo
[scriptblock]$dry_core_sb_configcombo_show ={
    [CmdLetBinding()]
    param(
    )
    try{
        if($null -ne $this.systemconfig.dependencies){
            $SystemDepOK = $this.TestDepHash('system')
        }
        else{
            $SystemDepOK = $true
        }
        ol d 'Are all system dependencies installed?',$SystemDepOK

        if($null -ne $this.envconfig.dependencies){
            $EnvDepOK = $this.TestDepHash('environment')
        }
        else{
            $EnvDepOK = $true
        }
        ol d 'Are all environment dependencies installed?',$EnvDepOK

        if($null -ne $this.moduleconfig.dependencies){
            $ModuleDepOK = $this.TestDepHash('module')
        }
        else{
            $ModuleDepOK = $true
        }
        ol d 'Are all module dependencies installed?',$ModuleDepOK

        ol i "Selected Configuration: $($this.Name)" -h
        ol i 'Name',$this.name
        ol i 'Path',$this.path
        ol i ' '

        ol i 'EnvConfig' -sh
        if($null -ne $this.envconfig.path){
            ol i 'Name',$this.envconfig.name
            ol i 'Path',$this.envconfig.path
            ol i 'Description',$this.envconfig.description
        }
        else{
            ol w "Use -EnvConfig to select an environment"
        }
        
        ol i ' '
        ol i 'ModuleConfig' -sh
        if($null -ne $this.moduleconfig.path){
            ol i 'Name',$this.moduleconfig.name
            ol i 'Path',$this.moduleconfig.path
            ol i 'Description',$this.moduleconfig.description
        }
        else{
            ol w "Use -ModuleConfig to select a module"
        }
        ol i ' ' 
        if($SystemDepOK -and $ModuleDepOK -and $EnvDepOK){
            ol i 'Does this config need -Init?','No' -ForegroundColor Green
        }
        else{
            ol i 'Does this config need -Init?','Yes' -ForegroundColor Red
        }
    }
    catch{
        throw $_
    }
}