[scriptblock]$dry_sb_utils_FileSystem_GetRandomPath = {
    [CmdLetBinding()]
    [OutputType([System.String])]
    
    param (
        [Parameter(HelpMessage="Length of the file or folder name, minus extension")]
        [Int]$Length,

        [Parameter(HelpMessage="Folder path, defaults to `$env:TEMP")]
        [String]$Path,

        [Parameter(HelpMessage="Extension of the file")]
        [Parameter()]
        [String]$Extension
    )

    try {
        if (-not $Length) {
            [int]$Length = 25
        }
        if ($Extension) {
            $Extension = $Extension.TrimStart('.')
        }
        if ($Path) {
            $Path = $THIS.FileSystem_ResolveFullPath($Path,'String',$true)
        }
        else {
            $Path = $THIS.FileSystem_ResolveFullPath($env:TEMP,'String',$false)
        }
        $RandomString = $THIS.Strings_NewRandomHex($Length)
        if ($Extension) {
            $RandomString = $RandomString + '.' + $Extension
        }
        return [String](Join-Path -Path $Path -ChildPath $RandomString)
    }
    catch {
        throw $_
    }
    finally {
      $Path = $null
      $RandomString = $null
      $Extension = $null
    }
}