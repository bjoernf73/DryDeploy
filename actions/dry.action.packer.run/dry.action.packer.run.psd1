@{
RootModule = 'dry.action.packer.run.psm1'
ModuleVersion = '0.1'
CompatiblePSEditions = 'Desktop','Core'
GUID = 'f7f415fc-7041-480b-a529-f15cafd4f66b'
Author = 'bjoernf73'
Copyright = '(c) 2021 bjoernf73. All rights reserved.'
Description = 'Runs a Packer null-provider script/config'
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
    'dry.action.packer.run'
)
CmdletsToExport = @()
VariablesToExport = ''
AliasesToExport = '*'
PrivateData = @{
    PSData = @{
        LicenseUri = 'https://raw.githubusercontent.com/bjoernf73/dry.action.packer.run/main/LICENSE'
        ProjectUri = 'https://github.com/bjoernf73/dry.action.packer.run'
    } 
} 
}