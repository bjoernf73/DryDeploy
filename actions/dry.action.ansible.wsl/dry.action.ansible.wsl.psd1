@{
RootModule = 'dry.action.ansible.wsl.psm1'
ModuleVersion = '0.1'
CompatiblePSEditions = 'Desktop','Core'
GUID = '8058cc78-d2e6-40b0-b679-6fa0630846d9'
Author = 'bjoernf73'
Copyright = '(c) 2025 bjoernf73. All rights reserved.'
Description = 'Runs an Ansible playbook on a WSL instance.'
RequiredModules = @(
    @{
        ModuleName    = "dry.module.log"; 
        ModuleVersion = "0.0.3"; 
        Guid          = "267d805a-196e-4d87-8d73-4ef45df727c3"
    },
    @{
        ModuleName    = "dry.module.core"; 
        ModuleVersion = "0.1"; 
        Guid          = "a97e4e2e-dffe-4e12-a2da-801c5beb3bf2"
    },
    @{
        ModuleName    = "dry.module.utils"; 
        ModuleVersion = "0.1"; 
        Guid          = "ae0b9f38-646f-4fdc-8a30-1472adba14cd"
    }
)
FunctionsToExport = @(
    'dry.action.ansible.wsl'
)
CmdletsToExport = @()
PrivateData = @{
    PSData = @{
        LicenseUri = 'https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/actions/dry.action.ansible.wsl/LICENSE'
        ProjectUri = 'https://raw.githubusercontent.com/bjoernf73/DryDeploy/main/actions/dry.action.ansible.wsl'
    } 
}}