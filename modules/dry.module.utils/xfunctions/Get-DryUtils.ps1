function Get-DryUtils {
    [CmdLetBinding()]
    param ()
    try {
        # Strings
        $DryUtils = [PSObject]@{}
        $DryUtils | Add-Member -MemberType ScriptMethod -Name 'Strings_NewRandomHex' -Value $dry_sb_utils_Strings_NewRandomHex
        
        # FileSystem
        $DryUtils | Add-Member -MemberType ScriptMethod -Name 'FileSystem_ResolveFullPath' -Value $dry_sb_utils_FileSystem_ResolveFullPath
        $DryUtils | Add-Member -MemberType ScriptMethod -Name 'FileSystem_GetRandomPath' -Value $dry_sb_utils_FileSystem_GetRandomPath

        # Help
        $DryUtils | Add-Member -MemberType ScriptMethod -Name 'Help' -Value $dry_sb_utils_Help
        return $DryUtils
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
} 

<# 
    #! This was my first try at this: 

    function Get-DryUtils {
        [CmdLetBinding()]
        param ()
        try {
            $StringsObj = [PSObject]@{}
            $StringsObj | Add-Member -MemberType ScriptMethod -Name 'NewRandomHex' -Value $dry_sb_utils_Strings_NewRandomHex
            # FileSystem
            $FileSystemObj  = [PSObject]@{}
            $FileSystemObj | Add-Member -MemberType ScriptMethod -Name 'ResolveFullPath' -Value $dry_sb_utils_FileSystem_ResolveFullPath
            $FileSystemObj | Add-Member -MemberType ScriptMethod -Name 'GetRandomPath' -Value $dry_sb_utils_FileSystem_GetRandomPath

            $DryUtils = [PSObject]@{
                Description = 'Utilities for DryDeploy'
                FileSystem  = $FileSystemObj
                Strings     = $StringsObj
            }
            return $DryUtils
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }


    However, the scripblock $dry_sb_utils_FileSystem_GetRandomPath in turn calls $dry_sb_utils_Strings_NewRandomHex, by doing
    $this.Strings.NewRandomHex() - but this fails. ScriptMethods inside a which doesn't work. However, if the scriptmethod is at the root, it works. So: 
    
    $DryUtils | Add-Member -MemberType ScriptMethod -Name 'Strings_NewRandomHex' -Value $dry_sb_utils_Strings_NewRandomHex
    $this.Strings_NewRandomHex()



#>