---
external help file: -help.xml
Module Name:
online version:
schema: 2.0.0
---

# DryDeploy.ps1

## SYNOPSIS
DryDeploy.ps1 prepares your deployment platform (-Init, -Moduleinit), 
stores paths to a configuration combination of a EnvConfig and a 
ModuleConfig, creates a plan of Actions to perform based on the 
configurations and any filters specified (-Plan), and applies the 
plan in the configured order (-Apply).
Run DryDeploy.ps1 without any 
parameters to show the deployment status of the current Plan.

## SYNTAX

### ShowPlan (Default)
```
DryDeploy.ps1 [-ShowDeselected] [<CommonParameters>]
```

### Init
```
DryDeploy.ps1 [-Init] [-ModuleInit] [<CommonParameters>]
```

### Plan
```
DryDeploy.ps1 [-Plan] [-Actions <String[]>] [-ExcludeActions <String[]>] [-BuildOrders <Int32[]>]
 [-ExcludeBuildOrders <Int32[]>] [-Resources <String[]>] [-ExcludeResources <String[]>] [-Phases <Int32[]>]
 [-ExcludePhases <Int32[]>] [-NoLog] [-ShowDeselected] [-CmTrace] [<CommonParameters>]
```

### Apply
```
DryDeploy.ps1 [-Apply] [-Actions <String[]>] [-ExcludeActions <String[]>] [-BuildOrders <Int32[]>]
 [-ExcludeBuildOrders <Int32[]>] [-Resources <String[]>] [-ExcludeResources <String[]>] [-Phases <Int32[]>]
 [-ExcludePhases <Int32[]>] [-ActionParams <Hashtable>] [-NoLog] [-KeepConfigFiles] [-KeepOnFailedBuilds]
 [-ShowAllErrors] [-ShowPasswords] [-ShowStatus] [-SuppressInteractivePrompts] [-IgnoreDependencies] [-Step]
 [-Quit] [-CmTrace] [-Force] [<CommonParameters>]
```

### SetConfig
```
DryDeploy.ps1 [-EnvConfigPath <String>] [-ModuleConfig <String>] [<CommonParameters>]
```

## DESCRIPTION
DryDeploy.ps1 needs 2 configuration repositories: 

 - EnvConfig: Contains information on an environment, 
   including variables as key-value-pairs, where values may be 
   expressions to resolve actual values, network information and
   platform definitions.
It also contains OS-specific configs, 
   so Actions may pick up the shared base-config, to use as is,
   or add role-specific configurations.
Also contains a list of
   the all Resources that the environment will contain.
As such,
   the Resources node only specify the instances of roles, but 
   each role must be represented in a ModuleConfig, which specifies
   how each resource is built, and the order of those Actions. 

 - ModuleConfig: Contains Roles and Build. 
   Roles are types of resources, and contain the configuration 
   files to be consumed by Actions that build each role of the 
   module.
The Build specifies the order in which 
   roles of a module are deployed, and the Ations, and the order 
   of those Actions, that builds and configures each Role.

## EXAMPLES

### EXAMPLE 1
```
.\DryDeploy.ps1 -Init
```

Will prepare your system for deployment.
Installs Choco, Git, 
Packer, downloads and installs modules, and dependent git repos.
Make sure to elevate your PowerShell for this one - it will fail
if not

### EXAMPLE 2
```
.\DryDeploy.ps1 -ModuleConfig ..\ModuleConfigs\MyModule -EnvConfigPath ..\EnvConfigs\MyEnvironment
```

Creates a configuration combination of a Module Configuration and
a Env Configuration.
The combination (the "ConfigCombo") is stored
and used on subsequent runs until you change any of them again

### EXAMPLE 3
```
.\DryDeploy.ps1 -ModuleInit
```

Will prepare your system for deployment of a specific ModuleConfig. 
Installs a module's dependencies, including chocos, gits, powershell 
modules and so on

### EXAMPLE 4
```
.\DryDeploy.ps1 -Plan
```

Will create a full plan for all resources in the configuration that
is of a role that matches roles in your ModuleConfig

### EXAMPLE 5
```
.\DryDeploy.ps1
```

Displays the current Plan

### EXAMPLE 6
```
.\DryDeploy.ps1 -Plan -Resources dc,ca
```

Creates a partial plan, containing only Resources whos name is 
or matches "dc*" or "ca*"

### EXAMPLE 7
```
.\DryDeploy.ps1 -Plan -Resources dc,ca -Actions vsp,ad
```

Creates a partial plan, containing only Resources whos name is 
or match "dc*" or "ca*", with only Actions whos name is or 
matches "vsph*" (for instance "vsphere.clone") or "ad*" (for instance 
"ad.import")

### EXAMPLE 8
```
.\DryDeploy.ps1 -Plan -ExcludeResources DC,DB
```

Creates a partial plan, excluding any Resource whos name is or 
matches "DC*" or "DB*"

### EXAMPLE 9
```
.\DryDeploy.ps1 -Apply
```

Applies the current Plan.

### EXAMPLE 10
```
.\DryDeploy.ps1 -Apply -Force
```

Applies the current Plan, destroying any resource with the same 
identity as the resource you are creating.

### EXAMPLE 11
```
.\DryDeploy.ps1 -Apply -Resources ca002 -Actions ad.import
```

Applies only actions of the Plan where the Resources name is or 
matches "ca002*", and the name of the Action that is or matches 
"ad.import"

## PARAMETERS

### -Init
Initiates, meaning that it installs dependencies, like Chocolatey, 
Packer, some external modules from PSGallery, and the core DryDeploy
modules.
Must be executed as an administrator (elevated).
The core 
modules are installed for the system.

```yaml
Type: SwitchParameter
Parameter Sets: Init
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModuleInit
Downloads dependencies for the system module you

are deploying.
If any chocos needs to be installed, you have to

run elevated (Run as Administrator)

```yaml
Type: SwitchParameter
Parameter Sets: Init
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Plan
Plan must be run at least once to combine the ModuleConfiguration 
and EnvConfiguration, and to determine the resources to create 
and configure, and the order of the Actions to process.

```yaml
Type: SwitchParameter
Parameter Sets: Plan
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Apply
Applies the Plan.

```yaml
Type: SwitchParameter
Parameter Sets: Apply
Aliases:

Required: True
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Actions
Array of one or more Actions to include.
All others are excluded. 
If not specified, all Actions are included.
Supports partial 
match ('Co' will match Action 'ConfigAD')

```yaml
Type: String[]
Parameter Sets: Plan, Apply
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeActions
Array of one or more Actions to exclude.
All others are included. 
If not specified, no actions are excluded.
Supports partial 
match ('Co' will match Action 'ConfigAD')

```yaml
Type: String[]
Parameter Sets: Plan, Apply
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BuildOrders
Array of one or more BuildOrders to include.
All others are 
excluded.
If not specified, all BuildOrders are included.

```yaml
Type: Int32[]
Parameter Sets: Plan, Apply
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeBuildOrders
Array of one or more BuildOrders to exclude.
All others are 
included.
If not specified, all BuildOrders are included.

```yaml
Type: Int32[]
Parameter Sets: Plan, Apply
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Resources
Array of one or more Resource names to include.
All others are 
excluded.
If not specified, all Resources are included.
Supports 
partial match ('DC' will match Resource 'DC001-S5-D')

```yaml
Type: String[]
Parameter Sets: Plan, Apply
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludeResources
Array of one or more Resource names to exclude.
All others are 
included.
If not specified, no Resources are excluded.
Supports 
partial match ('DC' will match Resource 'DC001-S5-D')

```yaml
Type: String[]
Parameter Sets: Plan, Apply
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Phases
Array of one or more Phases (of any Action) to include.
All other 
Phases (and non-phased actions) are excluded.
If not specified, 
all Phases are included

```yaml
Type: Int32[]
Parameter Sets: Plan, Apply
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ExcludePhases
Array of one or more Phases (of any Action) to exclude.
All other 
Phases (and non-phased actions) are included.
If not specified, 
no Phases are excluded

```yaml
Type: Int32[]
Parameter Sets: Plan, Apply
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -EnvConfigPath
Path to the Directory where the EnvConfiguration is.
Use to 
set the configuration combination (ConfigCombo)

```yaml
Type: String
Parameter Sets: SetConfig
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModuleConfig
Path to the Directory where the ModuleConfiguration is.
Use to 
set the configuration combination (ConfigCombo)

```yaml
Type: String
Parameter Sets: SetConfig
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ActionParams
HashTable that will be sent to the Action Function.
Useful during 
development, for instance if the receiving action function 
supports a parameter to specify a limited set of tasks to do.

```yaml
Type: Hashtable
Parameter Sets: Apply
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NoLog
By default, a log file will be written.
If you're opposed to that, 
use -NoLog.

```yaml
Type: SwitchParameter
Parameter Sets: Plan, Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -KeepConfigFiles
Will not delete temporary configuration files at end of Action. 
However, upon running the action again, if the target temp 
is populated with files, those files will still be deleted.

```yaml
Type: SwitchParameter
Parameter Sets: Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -KeepOnFailedBuilds
If your run builds something, that artifact will be deleted if 
the build operation fails.
Use this to keep the artifact of the
failed build instead of deleting it

```yaml
Type: SwitchParameter
Parameter Sets: Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowAllErrors
If an exception occurs, I try to display the terminating error. 
If -ShowAllErrors, I'll show all errors in the $Error variable.

```yaml
Type: SwitchParameter
Parameter Sets: Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowPasswords
Credentials are resolved from the Credentials node of the 
configuration by the function Get-DryCredential.
If 
-ShowPasswords, clear text passwords will be output to screen 
by that function.
Use with care

```yaml
Type: SwitchParameter
Parameter Sets: Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowStatus
Will show detailed status messages for each individual 
configuration task in some Actions.

```yaml
Type: SwitchParameter
Parameter Sets: Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ShowDeselected
When you -Plan, or run without any other params, just to show
the Plan, only Actions selected in the Plan will be displayed. 
If you do -ShowDeselected, the deselected Actions will be 
displayed in a table below your active Plan.

```yaml
Type: SwitchParameter
Parameter Sets: ShowPlan, Plan
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -SuppressInteractivePrompts
Will suppress any interactive prompt.
Useful when running in a 
CI/CD pipeline.
When for instance a credential is not found in 
the configuration's credentials node, an interactive prompt will 
prompt for it.
Use to suppress that prompt, and throw an error 
instead

```yaml
Type: SwitchParameter
Parameter Sets: Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -IgnoreDependencies
Ignores any dependency for both ModuleConfig and

DryDeploy itself

```yaml
Type: SwitchParameter
Parameter Sets: Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Step
When you -Apply, you may -Step to step through each Action with-
out automatically jumping to the next.
This will require you to
interactively confirm each jump to next Action.

```yaml
Type: SwitchParameter
Parameter Sets: Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Quit
When you -Apply, you may -Quit to make the script quit after 
every Action.
Useful for CI/CD Pipelines, since the run may 
be devided into blocks that are visually pleasing.

```yaml
Type: SwitchParameter
Parameter Sets: Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -CmTrace
Will open the log file in cmtrace som you may follow the output-
to-log interactively.
You will need CMTrace.exe on you system 
and in path

```yaml
Type: SwitchParameter
Parameter Sets: Plan, Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Will destroy existing resources.
Careful.

```yaml
Type: SwitchParameter
Parameter Sets: Apply
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
