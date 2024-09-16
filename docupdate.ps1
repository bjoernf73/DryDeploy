try {
    $README = "$PSScriptRoot\README.md"
    $Folder = "$PSScriptRoot\590bfb52\"
    $File   = "$Folder\DryDeploy.md"
    $NFile  = "$Folder\README.md"
    
    if (Test-Path -Path $Folder -ErrorAction Ignore) {
        Remove-Item -Path $Folder -Recurse -Force
    }
    Import-Module -Name "$PSScriptRoot\DryDeploy.psd1" 
    Import-Module -Name PlatyPS
    New-MarkdownHelp -Module DryDeploy -OutputFolder $Folder
    Remove-Item -Path $README -Force -Confirm:$false -ErrorAction SilentlyContinue
    Rename-Item -Path $File -NewName 'README.md' -ErrorAction SilentlyContinue
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