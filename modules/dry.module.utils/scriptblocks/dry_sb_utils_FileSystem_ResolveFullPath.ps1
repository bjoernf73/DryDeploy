[scriptblock]$dry_sb_utils_FileSystem_ResolveFullPath = {
    [CmdLetBinding()]
    [OutputType([System.String],[System.Management.Automation.PathInfo],[System.IO.FileInfo],[System.IO.DirectoryInfo])]
    
    param (
        [Parameter(Mandatory,HelpMessage="Releative or absolute path of any kind")]
        [ValidateNotNullOrEmpty()]
        [String]$Path,

        [Parameter(HelpMessage="The type to return. Only existing objects may return")]
        [ValidateSet('String','PathInfo','FileInfo','DirectoryInfo',$null)]
        [String]$OutputType,

        [Parameter(HelpMessage="Ensures the path is resolved and returned as a string even though the item doesn't exist")]
        [Switch]$Force
    )
    try {
        if (-not $OutputType) {
            $OutputType = 'String'
        }
        try {
            [System.Management.Automation.PathInfo]$PathInfo = Resolve-Path -Path $Path -ErrorAction Stop
            try {
                switch ($OutputType) {
                    'PathInfo' {
                        [System.Management.Automation.PathInfo]$FullPath = $PathInfo
                    }
                    'FileInfo' {
                        [System.IO.FileInfo]$FullPath = Get-Item -Path $PathInfo -ErrorAction Stop
                    }
                    'DirectoryInfo' {
                        [System.IO.DirectoryInfo]$FullPath = Get-Item -Path $PathInfo -ErrorAction Stop
                    }
                    default {
                        [System.String]$FullPath = $PathInfo.Path
                    }
                }
            }
            catch {
                throw $_
            }
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            if ($Force) {
                [String]$FullPath = $_.TargetObject
                if ($OutputType -ne 'String') {
                    throw "The path '$FullPath' does not exist, and cannot be converted to '$OutputType'"
                }
            }
            else {
                throw $_
            }
        }
        catch {
            throw $_
        }
        return $FullPath
    }
    catch {
        throw $_
    }
    finally {
        $PathInfo = $null
        $FullPath = $null
    }
}