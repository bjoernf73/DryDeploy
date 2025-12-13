<# 
 This module provides core functionality for DryDeploy.

 
#>
function Resolve-DryFullPath{
    [cmdletbinding()]
    param(
        [string] 
        $Path,

        [System.IO.DirectoryInfo] 
        $RootPath
    )

    try{
        # if no RootPath is specified, use the current working directory
        if(-not ($RootPath)){
            [System.IO.DirectoryInfo]$RootPath = ($PWD).Path
        }

        # determine the slash - backslash on windows, slash on Linux
        $slash = '\'
        if($PSVersionTable.Platform -eq 'Unix'){
            $slash = '/'
        }
        
        # Path cannot be a system.io-object, because it does not necessarily exist
        if($Path -match "^\."){
            # Path relative to the current directory
            $FullPath = [IO.Path]::GetFullPath("$RootPath$($slash)$Path")
        }
        else{
            # Full path
            $FullPath = [IO.Path]::GetFullPath("$Path")
        }
        return $FullPath
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}