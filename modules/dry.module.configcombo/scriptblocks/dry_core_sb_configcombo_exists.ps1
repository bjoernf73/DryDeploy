# Scriptblock for ScriptMethod to test if the ConfigCombo json exists
[scriptblock]$dry_core_sb_configcombo_exists = {
    try {
        if (Test-Path -Path $this.Path -ErrorAction SilentlyContinue) {
            return $true
        }
        else {
            return $false
        }
    }
    catch {
        throw $_
    }
}