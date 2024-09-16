try {
    $Script = "$PSScriptRoot\DryDeploy.psm1"
    $README = "$PSScriptRoot\README.md"
    $Folder = "$PSScriptRoot\590bfb52\"
    $File   = "$Folder\DryDeploy.ps1.md"
    $NFile  = "$Folder\README.md"
    
    if (Test-Path -Path $Folder -ErrorAction Ignore) {
        Remove-Item -Path $Folder -Recurse -Force
    }
    Import-Module -Name PlatyPS
    New-MarkdownHelp -Command $Script -OutputFolder $Folder
    Remove-Item -Path $README -Force -Confirm:$false
    Rename-Item -Path $File -NewName 'README.md'
    Move-Item -Path $NFile -Destination $PSScriptRoot
    if (Test-Path -Path $Folder -ErrorAction Ignore) {
        Remove-Item -Path $Folder -Recurse -Force
    }
    git commit -am "mardown README.md updated $((Get-Date -Format s) -replace ':','-')"
    git push origin
}
catch {
    $PSCmdlet.ThrowTerminatingError($_)
}