# ScriptBlock for calculating a dependencies hash
[scriptblock]$dry_core_sb_configcombo_calcdephash ={
    [CmdLetBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [PSObject]$Dependencies
    )
    try{
        # accumulate a string that represents the host and all packages
        $HostName = ([System.NET.DNS]::GetHostByName('')).HostName
        $DependenciesString = $HostName

        foreach($Dependency in $Dependencies.nuget.modules){
            $DependenciesString += $Dependency.name
            if($Dependency.minimumversion){
                $DependenciesString += $Dependency.minimumversion
            }
            if($Dependency.maximumversion){
                $DependenciesString += $Dependency.maximumversion
            }
            if($Dependency.requiredversion){
                $DependenciesString += $Dependency.requiredversion
            }
        }

        foreach($Dependency in $Dependencies.choco.packages){
            $DependenciesString += $Dependency.name
            if($Dependency.version){
                $DependenciesString += $Dependency.version
            }
        }

        foreach($Dependency in $Dependencies.git.projects){
            $DependenciesString += $Dependency.url
            $DependenciesString += $Dependency.branch
        }

        # calculate a sha256 hash of the string
        $DotNetHasher     = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
        $ByteArray        = $DotNetHasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($DependenciesString))
        $DependenciesHash = [System.BitConverter]::ToString($ByteArray)
        return $DependenciesHash
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
        ol d @('Dependency string',"$DependenciesString")
        ol d @('Dependency hash',"$DependenciesHash")
        $DependenciesString = $null
        $DependenciesHash   = $null
        $DotNetHasher       = $null
        $ByteArray          = $null
    }
}