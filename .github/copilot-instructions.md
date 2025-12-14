# DryDeploy - AI Coding Agent Instructions

## Project Overview
**DryDeploy** is a PowerShell-based orchestration framework for multi-technology infrastructure deployments. It separates environment configurations (EnvConfig) from module/role blueprints (ModuleConfig), enabling deployment across dev/test/ref/production environments using a Plan-Apply workflow.

Core technologies orchestrated: Terraform, DSC, Packer, Ansible, SaltStack, and native AD/Windows actions.

## Architecture & Critical Concepts

### Configuration Separation (THE Core Pattern)
The entire system revolves around this separation:
- **EnvConfig**: Environment-specific values (networks, credentials, resource instances)
- **ModuleConfig**: Technology-agnostic role blueprints (what to build, in what order)
- **ConfigCombo**: Runtime merger of EnvConfig + ModuleConfig

Located in `~\DryDeploy\dry_deploy_config_combo.json` once set via:
```powershell
.\DryDeploy.ps1 -EnvConfig <path> -ModuleConfig <path>
```

### Terminology (see [doc/glossary.md](doc/glossary.md))
- **Role**: Blueprint/template (e.g., "dc-domctrl-froot" for first domain controller)
- **Resource**: Instantiated role with unique identity (the actual server/VM)
- **Action**: Technology operation (terra.run, dsc.run, ad.import, packer.run, etc.)
- **BuildStep**: Ordered execution position in the plan
- **Phase**: Optional sub-ordering within an action (e.g., `dsc.run` phase 1, then phase 2)

### Execution Model
1. **-Init**: Install all dependencies (once per workstation, elevated)
2. **-Plan**: Create ordered execution plan from configs + filters
3. **-Resolve**: Validate credential/variable resolution without execution
4. **-Apply**: Execute the plan (idempotent, resumable on failure)

```powershell
.\DryDeploy.ps1 -Plan -Resources dc,ca -Actions terra,dsc
.\DryDeploy.ps1 -Apply
```

On failure, fix code and re-run `-Apply` - it retries failed actions and continues.

### Build Dependencies ([doc/Build.md](doc/Build.md))
Actions declare dependencies via `depends_on`:
- **dependency_type**: `first|last|every|numbered|chained`
- **Example**: Sub-CA's `dsc.run` depends on Root CA's `dsc.run phase:1` completing

```json
{
  "action": "dsc.run",
  "depends_on": {
    "role": "ca-certauth-root",
    "dependency_type": "every",
    "action": "dsc.run",
    "phase": 1
  }
}
```

**order_type** in Build:
- `"role"`: Complete all instances of role1 before role2
- `"site"`: Complete all roles at site1 before site2

## Module & Action Structure

### Module Naming Convention
All modules/actions follow: `dry.[module|action].<name>`

Examples:
- `dry.module.plan`, `dry.module.ad`, `dry.module.credential`
- `dry.action.dsc.run`, `dry.action.terra.run`, `dry.action.ad.import`

### Module Internal Layout
Every dry.module.* or dry.action.* follows this pattern:

```
dry.module.example/
├── dry.module.example.psd1  # Manifest with FunctionsToExport
├── dry.module.example.psm1  # Dot-sources xfunctions/
├── xfunctions/              # Exported functions (one per file)
│   ├── Get-Something.ps1
│   └── Set-Something.ps1
├── functions/               # Internal/helper functions (if needed)
├── classes/                 # PowerShell classes (if needed)
├── helpers/                 # Helper modules (if needed)
├── scriptblocks/            # Reusable scriptblocks (if needed)
└── example/                 # Usage examples (if present)
```

**Critical**: The `.psm1` file ALWAYS dot-sources `xfunctions/*.ps1`:
```powershell
$ExportedFunctionsPath = "$PSScriptRoot\xfunctions\*.ps1"
$Functions = Resolve-Path -Path $ExportedFunctionsPath -ErrorAction Stop
foreach($function in $Functions){
    . $Function.Path
}
```

Actions may also have `ExportedFunctions/` instead of `xfunctions/` (see [dry.action.dsc.run](actions/dry.action.dsc.run)).

### Adding New Functions
When creating functions in a module:
1. Place in `xfunctions/` directory (one function per file)
2. Name file exactly as function: `Get-DryPlan.ps1` contains `function Get-DryPlan{...}`
3. Update `.psd1` manifest's `FunctionsToExport` array
4. The `.psm1` automatically dot-sources all files in `xfunctions/`

### Key Classes
Located in [modules/dry.module.plan/classes/dry.module.plan.class.action_and_plan.ps1](modules/dry.module.plan/classes/dry.module.plan.class.action_and_plan.ps1):
- `DryAction`: Represents executable actions with dependencies
- `Plan`: Manages action ordering and execution

**Action Ordering System**:
Actions use a simplified sequential integer ordering (1, 2, 3, 4...) with `Action_Guid` format: `00000001-<guid>`, `00000002-<guid>`, etc.

When dependencies require inserting an action between existing ones:
1. The new action takes the next position (e.g., if inserting after position 2, it becomes position 3)
2. All existing actions at position 3+ are incremented by 1
3. `Action_Guid` values are updated to reflect new positions

Example: Inserting action between positions 2 and 3:
- Before: `00000001-...`, `00000002-...`, `00000003-...`, `00000004-...`
- After: `00000001-...`, `00000002-...`, `00000003-<new>`, `00000004-...`, `00000005-...`

## Development Workflows

### Module Discovery
Modules loaded from:
```powershell
$Platform.LocalModulesDirectories = @(
    "$PSScriptRoot\modules",
    "$PSScriptRoot\actions"
)
```
Added to `$env:PSModulePath` at runtime (see [DryDeploy.ps1](DryDeploy.ps1) lines 700-800).

### Git Submodules for Roles
Roles are typically git submodules. See [doc/on-submodules.md](doc/on-submodules.md):
```powershell
git submodule add -b main [URL to role repo]
git submodule update --remote --merge
```

### Configuration Variables
Variables resolved from EnvConfig using expressions in ModuleConfig. See examples in [modules/dry.module.ad/example/](modules/dry.module.ad/example/).

Variable files are JSON arrays:
```json
[
  {"name": "org", "value": "TEST"},
  {"name": "RoleShortName", "value": "DC"}
]
```

### Error Handling
To catch specific exceptions, use:
```powershell
$Error[0].Exception.GetType().FullName
```
See [doc/OnErrors.md](doc/OnErrors.md) for examples.

### Dependencies Management
System dependencies defined in [SystemOptions.json](SystemOptions.json):
- PowerShell modules from PSGallery (nuget.modules)
- Chocolatey packages (choco.packages)
- Git repositories as modules

## Testing & Debugging

### Plan Inspection
```powershell
.\DryDeploy.ps1                    # Show current plan
.\DryDeploy.ps1 -ShowDeselected   # Include filtered-out actions
```

### Partial Plans (Filters)
Combine include/exclude filters:
- `-Resources`, `-ExcludeResources` (supports partial match: 'dc' matches 'dc1-s5-d')
- `-Roles`, `-ExcludeRoles`
- `-Actions`, `-ExcludeActions`
- `-BuildSteps`, `-ExcludeBuildSteps`
- `-Phases`, `-ExcludePhases`

### Configuration Validation
```powershell
.\DryDeploy.ps1 -Resolve           # Test variable resolution
$Config = .\DryDeploy.ps1 -GetConfig  # Export config for inspection
```

### Logging
Logs written to working directory (`~\DryDeploy`) by default:
- Use `-CmTrace` to launch CMTrace.exe with log
- Use `-NoLog` to disable
- Use `-ShowPasswords` (with `-Debug`) to expose credentials in logs

### Stepping Through Plans
```powershell
.\DryDeploy.ps1 -Apply -Step       # Confirm before each action
.\DryDeploy.ps1 -Apply -Quit       # Stop after each action
.\DryDeploy.ps1 -Rewind            # Move back one BuildStep
.\DryDeploy.ps1 -FastFwd           # Skip forward one BuildStep
```

## Common Patterns

### Action Implementation
Actions receive parameters via splatting from DryDeploy.ps1 (see line 1355):
```powershell
$ActionName = "dry.action.$($Action.Action)"
& $ActionName @ActionSplat
```

Actions must accept: `$Credentials`, `$Options`, `$Variables`, `$ActionParams` (if used).

### Module Loading Pattern
DryDeploy dynamically imports modules at runtime, not via `#Requires`. Modules removed after action execution (line 1535).

### Platform Abstraction
Use `$Platform` object for cross-platform paths:
```powershell
$Platform.Slash      # '\' on Windows, '/' on Unix
$Platform.Home       # $env:UserProfile or $env:HOME
$Platform.Platform   # 'Win32NT' or 'Unix'
```

## Documentation References
- [README.md](README.md): High-level concepts and workflow
- [doc/Build.md](doc/Build.md): Build definitions and dependencies
- [doc/ModuleConfig.md](doc/ModuleConfig.md): Module structure
- [doc/glossary.md](doc/glossary.md): Terminology
- [doc/on-submodules.md](doc/on-submodules.md): Git submodule workflows
- [doc/OnErrors.md](doc/OnErrors.md): Error handling examples
