# Scriptblock for ScriptMethod to save the ConfigCombo
[scriptblock]$dry_core_sb_configcombo_save ={
    try{
        Save-DryUtilsToJson -Path $This.Path -InputObject $This -Force
    }
    catch{
        throw $_
    }
}