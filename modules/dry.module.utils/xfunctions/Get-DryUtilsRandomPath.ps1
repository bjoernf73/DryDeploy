function Get-DryUtilsRandomPath {
    [CmdLetBinding()]
    [OutputType([System.String])]
    
    param (
        [Parameter(HelpMessage="Length of the file or folder name, minus extension")]
        [Int]$Length,

        [Parameter(HelpMessage="Folder path, defaults to `$env:TEMP")]
        [String]$Path,

        [Parameter(HelpMessage="Extension of the file")]
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
            $Path = Resolve-DryUtilsFullPath -Path $Path -OutputType 'String' -Force
        }
        else {
            $Path = Resolve-DryUtilsFullPath -Path $env:TEMP -OutputType 'String'
        }
        $RandomString = New-DryUtilsRandomHex -Length $Length
        if ($Extension) {
            $RandomString = $RandomString + '.' + $Extension
        }
        return [String](Join-Path -Path $Path -ChildPath $RandomString)
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
      $Path = $null
      $RandomString = $null
      $Extension = $null
    }
}