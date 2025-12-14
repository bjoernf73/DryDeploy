@{
    RootModule = 'DryDeploy.psm1'
    ModuleVersion = '1.0.0'
    GUID = '23e90b80-096c-4d1f-89df-59069dded64b'
    Author = 'bjoernf73'
    CompanyName = 'databjorn'
    Copyright = '(c) 2025 bjoernf73. Licensed under the GNU General Public License v2.0.'
    Description = 'DryDeploy is a promiscuous deployment orchestrator for PowerShell - swinging among available deployment technologies'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('DryDeploy')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @('dry')
    PrivateData = @{
        PSData = @{
            Tags = @(
                'Deployment', 
                'Windows Deployment', 
                'Automation', 
                'Windows Automation', 
                'Orchestration', 
                'Windows Orchestration',
                'Powershell',
                'anti-SCCM', 
                'DSC',
                'Desired State Configuration',
                'packer', 
                'terraform', 
                'ansible'
            )
            LicenseUri = 'https://github.com/bjoernf73/DryDeploy/blob/main/LICENSE'
            ProjectUri = 'https://github.com/bjoernf73/DryDeploy'
            IconUri = 'https://github.com/bjoernf73/DryDeploy/blob/main/DryDeploy.jpg'
            ReleaseNotes = 'Initial module release'
        }
    }
}
