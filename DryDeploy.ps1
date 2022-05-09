<#
.SYNOPSIS
DD prepares your deployment platform (-Init), 
stores paths to a configuration combination of a EnvConfig and a 
ModuleConfig, creates a plan of Actions to perform based on the 
configurations and any filters specified (-Plan), and applies the 
plan in the configured order (-Apply). Run DryDeploy.ps1 without any 
parameters to show the deployment status of the current Plan.

.DESCRIPTION
DD needs 2 configuration repositories: 

 - EnvConfig: Contains information on an environment, 
   including variables as key-value-pairs, where values may be 
   expressions to resolve actual values, network information and
   platform definitions. It also contains OS-specific configs, 
   so Actions may pick up the shared base-config, to use as is,
   or add role-specific configurations. Also contains a list of
   the all Resources that the environment will contain. As such,
   the Resources node only specify the instances of roles, but 
   each role must be represented in a ModuleConfig, which specifies
   how each resource is built, and the order of those Actions. 

 - ModuleConfig: Contains Roles and Build. 
   Roles are types of resources, and contain the configuration 
   files to be consumed by Actions that build each role of the 
   module. The Build specifies the order in which 
   roles of a module are deployed, and the Ations, and the order 
   of those Actions, that builds and configures each Role.
   
.PARAMETER Init
Installs local dependencies for the platform on which you run DD on. 

.PARAMETER Plan
Plan must be run at least once to combine the ModuleConfiguration 
and EnvConfiguration, and to determine the resources to create 
and configure, and the order of the Actions to process. 

.PARAMETER Apply
Applies the Plan. 

.PARAMETER Actions
Array of one or more Actions to include. All others are excluded. 
If not specified, all Actions are included. Supports partial 
match ('Co' will match Action 'ConfigAD')

.PARAMETER ExcludeActions
Array of one or more Actions to exclude. All others are included. 
If not specified, no actions are excluded. Supports partial 
match ('Co' will match Action 'ConfigAD')

.PARAMETER BuildSteps
Array of one or more BuildSteps to include. All others are 
excluded. If not specified, all BuildSteps are included. 

.PARAMETER ExcludeBuildSteps
Array of one or more BuildSteps to exclude. All others are 
included. If not specified, all BuildSteps are included. 

.PARAMETER Resources
Array of one or more Resource names to include. All others are 
excluded. If not specified, all Resources are included. Supports 
partial match ('DC' will match Resource 'DC001-S5-D')

.PARAMETER ExcludeResources
Array of one or more Resource names to exclude. All others are 
included. If not specified, no Resources are excluded. Supports 
partial match ('DC' will match Resource 'DC001-S5-D')

.PARAMETER Phases
Array of one or more Phases (of any Action) to include. All other 
Phases (and non-phased actions) are excluded. If not specified, 
all Phases are included

.PARAMETER ExcludePhases
Array of one or more Phases (of any Action) to exclude. All other 
Phases (and non-phased actions) are included. If not specified, 
no Phases are excluded

.PARAMETER EnvConfig
Path to the Directory where the EnvConfiguration is. Use to 
set the configuration combination (ConfigCombo)

.PARAMETER ModuleConfig
Path to the Directory where the ModuleConfiguration is. Use to 
set the configuration combination (ConfigCombo)

.PARAMETER ActionParams
HashTable that will be sent to the Action Function. Useful during 
development, for instance if the receiving action function 
supports a parameter to specify a limited set of tasks to do. 

.PARAMETER GetConfig
During -Plan and -Apply, selected configurations from the current 
Environment and Module are combined into one configuration object.
Run -GetConfig to just return this configuration object, and then 
quit. Assign the output to a variable to examine the configuration.

.PARAMETER NoLog
By default, a log file will be written. If you're opposed to that, 
use -NoLog.

.PARAMETER KeepConfigFiles
Will not delete temporary configuration files at end of Action. 
However, upon running the action again, if the target temp 
is populated with files, those files will still be deleted.

.PARAMETER DestroyOnFailedBuild
If your run builds something, for instance with packer, that 
artifact will be kept if the build fails, so you may examine 
it's failed state. Use to destroy the fail-built artifact instead"

.PARAMETER ShowAllErrors
If an exception occurs, I try to display the terminating error. 
If -ShowAllErrors, I'll show all errors in the $Error variable. 

.PARAMETER ShowPasswords
Credentials are resolved from the Credentials node of the 
configuration by the function Get-DryCredential. If 
-ShowPasswords, clear text passwords will be output to screen 
by that function. Use with care

.PARAMETER ShowStatus
Will show detailed status messages for each individual 
configuration task in some Actions. 

.PARAMETER ShowDeselected
When you -Plan, or run without any other params, just to show
the Plan, only Actions selected in the Plan will be displayed. 
If you do -ShowDeselected, the deselected Actions will be 
displayed in a table below your active Plan.

.PARAMETER SuppressInteractivePrompts
Will suppress any interactive prompt. Useful when running in a 
CI/CD pipeline. When for instance a credential is not found in 
the configuration's credentials node, an interactive prompt will 
prompt for it. Use to suppress that prompt, and throw an error 
instead

.PARAMETER Step
When you -Apply, you may -Step to step through each Action with-
out automatically jumping to the next. This will require you to
interactively confirm each jump to next Action. 

.PARAMETER Quit
When you -Apply, you may -Quit to make the script quit after 
every Action. Useful for CI/CD Pipelines, since the run may 
be devided into blocks that are visually pleasing. 

.PARAMETER CMTrace
Will open the log file in cmtrace som you may follow the output-
to-log interactively. You will need CMTrace.exe on you system 
and in path 

.PARAMETER Force
Will destroy existing resources. Careful.

.EXAMPLE
.\DryDeploy.ps1 -Init
Will prepare your system for deployment. Installs Choco, Git, 
Packer, downloads and installs modules, and dependent git repos.
Make sure to elevate your PowerShell for this one - it will fail
if not

.EXAMPLE
.\DryDeploy.ps1 -ModuleConfig ..\ModuleConfigs\MyModule -EnvConfig ..\EnvConfigs\MyEnvironment
Creates a configuration combination of a Module Configuration and
a Env Configuration. The combination (the "ConfigCombo") is stored
and used on subsequent runs until you change any of them again

.EXAMPLE
.\DryDeploy.ps1 -Plan
Will create a full plan for all resources in the configuration that
is of a role that matches roles in your ModuleConfig

.EXAMPLE
.\DryDeploy.ps1
Displays the current Plan

.EXAMPLE
.\DryDeploy.ps1 -Plan -Resources dc,ca
Creates a partial plan, containing only Resources whos name is 
or matches "dc*" or "ca*"

.EXAMPLE
.\DryDeploy.ps1 -Plan -Resources dc,ca -Actions vsp,ad
Creates a partial plan, containing only Resources whos name is 
or match "dc*" or "ca*", with only Actions whos name is or 
matches "vsph*" (for instance "vsphere.clone") or "ad*" (for instance 
"ad.import")

.EXAMPLE
.\DryDeploy.ps1 -Plan -ExcludeResources DC,DB
Creates a partial plan, excluding any Resource whos name is or 
matches "DC*" or "DB*"

.EXAMPLE
.\DryDeploy.ps1 -Apply
Applies the current Plan. 

.EXAMPLE
.\DryDeploy.ps1 -Apply -Force
Applies the current Plan, destroying any resource with the same 
identity as the resource you are creating. 

.EXAMPLE
.\DryDeploy.ps1 -Apply -Resources ca002 -Actions ad.import
Applies only actions of the Plan where the Resources name is or 
matches "ca002*", and the name of the Action that is or matches 
"ad.import"

.EXAMPLE
$Config = .\DryDeploy.ps1 -GetConfig
Returns the configuration object, and assigns it to the variable 
'$Config' so you may inspect it's content 'offline' 
#>
[CmdLetBinding(DefaultParameterSetName='ShowPlan')]
param (
    
    [Parameter(ParameterSetName='Init',
    HelpMessage='Downloads dependencies for DD. Must run 
    once on the system you are working from, and must run elevated 
    (Run as Administrator)')]
    [Switch]
    $Init,
    
    [Parameter(Mandatory,ParameterSetName='Plan',
    HelpMessage='Create an ordered plan based on your configuration 
    and selections made by -Actions and -Resources')]
    [Switch]
    $Plan,

    [Parameter(Mandatory,ParameterSetName='Apply',
    HelpMessage="To start applying (performing actions) according 
    to plan. If you don't, I'll only plan.")]
    [Switch]
    $Apply,

    [Parameter(ParameterSetName='Plan',
    HelpMessage='Array of one or more Actions to include. All others 
    are excluded. If not specified, all actions are included')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Array of one or more Actions to include. All others 
    are excluded. If not specified, all actions are included')]
    [ArgumentCompleter({(Get-ChildItem -Path ".\actions\*" | 
        Select-Object -ExpandProperty Name) | 
        foreach-Object { $_ -Replace "^dry\.action\.",''}})]
    [String[]]
    $Actions,

    [Parameter(ParameterSetName='Plan',
    HelpMessage='Array of one or more Actions to exclude. All others 
    are included. If not specified, no actions are excluded')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Array of one or more Actions to exclude. All others 
    are included. If not specified, no actions are excluded')]
    [ArgumentCompleter({(Get-ChildItem -Path ".\actions\*" | 
        Select-Object -ExpandProperty Name) | 
        foreach-Object { $_ -Replace "^dry\.action\.",''}})]
    [String[]]
    $ExcludeActions, 

    [Parameter(ParameterSetName='Plan',
    HelpMessage='Array of one or more ActionsOrders to include. All 
    others are excluded. If not specified, all ActionsOrders are 
    included.')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Array of one or more ActionsOrders to include. All 
    others are excluded. If not specified, all ActionsOrders are 
    included.')]
    [Int[]]
    $BuildSteps,

    [Parameter(ParameterSetName='Plan',
    HelpMessage='Array of one or more ActionsOrders to exclude. All 
    others are included. If not specified, all ActionsOrders are 
    included.')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Array of one or more ActionsOrders to exclude. All 
    others are included. If not specified, all ActionsOrders are 
    included.')]
    [Int[]]
    $ExcludeBuildSteps,

    [Parameter(ParameterSetName='Plan',
    HelpMessage='Array of one or more Resource names to include. 
    All others are excluded. If not specified, all Resources are 
    included')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Array of one or more Resource names to include. 
    All others are excluded. If not specified, all Resources are 
    included')]
    #! The argumentcompleter does not work anymore
    [ArgumentCompleter({((Get-Content -Path (Join-Path ((Get-Content (Join-Path (Join-Path $($env:USERPROFILE) DryDeploy) ConfigCombo.json) | ConvertFrom-Json).InstanceConfig.Path) `
        resources.json) | ConvertFrom-Json).resources) | 
        Select-Object -ExpandProperty Name })]
    [String[]]
    $Resources,

    [Parameter(ParameterSetName='Plan',
    HelpMessage='Array of one or more Resource names to exclude. 
    All others are included. If not specified, no Resources are 
    excluded')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Array of one or more Resource names to exclude. 
    All others are included. If not specified, no Resources are 
    excluded')]
    #! The argumentcompleter does not work anymore
    [ArgumentCompleter({((Get-Content -Path (Join-Path ((Get-Content `
        (Join-Path (Join-Path $($env:localappdata) DryDeploy) `
        ConfigCombo.json) | ConvertFrom-Json).InstanceConfig.Path) `
        resources.json) | ConvertFrom-Json).resources) | 
        Select-Object -ExpandProperty Name })]
    [String[]]
    $ExcludeResources,

    [Parameter(ParameterSetName='Plan',
    HelpMessage='Array of one or more Phases (of any Action) to 
    include. All other Phases (and non-phased actions) are excluded. 
    If not specified, all Phases are included')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Array of one or more Phases (of any Action) to 
    include. All other Phases (and non-phased actions) are excluded. 
    If not specified, all Phases are included')]
    [Int[]]
    $Phases,

    [Parameter(ParameterSetName='Plan',
    HelpMessage='Array of one or more Phases (of any Action) to 
    exclude. All other Phases (and non-phased actions) are included. 
    If not specified, no Phases are excluded')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Array of one or more Phases (of any Action) to 
    exclude. All other Phases (and non-phased actions) are included. 
    If not specified, no Phases are excluded')]
    [Int[]]
    $ExcludePhases,

    [Parameter(ParameterSetName='SetConfig',
    HelpMessage="Path to the directory where the EnvConfig is. 
    Once set, the ConfigCombo (the combination of a EnvConfig, 
    a ModuleConfig and an InstanceConfig) will be stored and reused  
    for each subsequent action")]
    [String]
    $EnvConfig,

    [Parameter(ParameterSetName='SetConfig',
    HelpMessage="Path to the directory where the ModuleConfig is. 
    Once set, the ConfigCombo (the combination of a EnvConfig, 
    a ModuleConfig and an InstanceConfig) will be stored and reused  
    for each subsequent action")]
    [String]
    $ModuleConfig,

    [Parameter(ParameterSetName='Apply',
    HelpMessage="Specify a hashtable of parameters to splat to 
    Actions. All receiving action function must accept all parameters. 
    So use only when running individual actions")]
    [Hashtable]
    $ActionParams,

    [Parameter(ParameterSetName='GetConfig',
    HelpMessage='Returns the combined configuration object and quits')]
    [Switch]
    $GetConfig,


    [Parameter(ParameterSetName='Plan',
    HelpMessage='Disable logging to file')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Disable logging to file')]
    [Switch]
    $NoLog,

    [Parameter(ParameterSetName='Apply',
    HelpMessage="Configuration files for actions that require files, 
    are copied to a temporary directory before they are used. In 
    an Action's finally block, those files are deleted. Unless you 
    use this switch")]
    [Switch]
    $KeepConfigFiles,

    [Parameter(ParameterSetName='Apply',
    HelpMessage="If your run builds something, for instance with packer, 
    that artifact will be kept if the build fails, so you may examine 
    it's failed state. Use to destroy the fail-built artifact instead")]
    [Switch]
    $DestroyOnFailedBuild,

    [Parameter(ParameterSetName='Apply',
    HelpMessage='Show all errors in the $Error variable if a 
    terminating error occures')]
    [Switch]
    $ShowAllErrors,

    [Parameter(ParameterSetName='Apply',
    HelpMessage='Will show passwords in the debug log stream. Has 
    no effect without -debug.')]
    [Switch]
    $ShowPasswords,

    [Parameter(ParameterSetName='Apply',
    HelpMessage='Will show detailed status messages for each 
    individual configuration task in some Actions')]
    [Switch]
    $ShowStatus,

    [Parameter(ParameterSetName='ShowPlan',
    HelpMessage='Shows deselected Actions (not in Plan) as well as 
    planned Actions')]
    [Parameter(ParameterSetName='Plan',
    HelpMessage='Shows deselected Actions (not in Plan) as well as 
    planned Actions')]
    [Switch]
    $ShowDeselected,

    [Parameter(ParameterSetName='Apply',
    HelpMessage="Will suppress any interactive prompt. Useful when
    running in a CI/CD pipeline. When for instance a credential is not 
    found in the InstanceConfig's credentials node, an interactive
    prompt will ask for it. Use to suppress that prompt, and throw
    an error instead")]
    [Switch]
    $SuppressInteractivePrompts,

    [Parameter(ParameterSetName='Apply',
    HelpMessage="Ignores any dependency for both ModuleConfig and 
    DD itself")]
    [Switch]
    $IgnoreDependencies,

    [Parameter(ParameterSetName='Apply',
    HelpMessage='Step through each Action, and require confirmation 
    before continuing to the next')]
    [Switch]
    $Step,

    [Parameter(ParameterSetName='Apply',
    HelpMessage='Quit after each Action. To continue, -Apply again. 
    Useful for CI/CD Pipelines to separate runs into blocks')]
    [Switch]
    $Quit,

    [Parameter(ParameterSetName='Plan',
    HelpMessage='Launches CmTrace.exe with the log file at the start 
    of execution, if CmTrace.exe exists in path')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Launches CmTrace.exe with the log file at the start 
    of execution, if CmTrace.exe exists in path')]
    [Switch]
    $CmTrace,

    [Parameter(ParameterSetName='Apply',
    HelpMessage='Force will seek and destroy')]
    [Switch]
    $Force
)

<# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    
    PreModulesFunctions
    
    Functions that are needed in-script to ensure proper resolving of paths to where DD's
    modules are, and such. For instance, $PSScriptRoot does not always exist, as you may 
    have experienced. If that is the case, we try $MyInvocation, and so on. 
    
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>

#region PreModulesFunctions
function Get-DryScriptPath {
    [CmdletBinding()]
    param (
    )
    try {
        if (($null -ne $PSScriptRoot) -And (Test-Path -Path $PSScriptRoot -ErrorAction 'Ignore')) {
            $PSScriptRoot
        }
        elseif (((Split-Path -Path $MyInvocation.MyCommand.Path) -match "^[a-zA-Z]\:\\") -or
                ((Split-Path -Path $MyInvocation.MyCommand.Path) -match "^/")) {
            Split-Path -Path $MyInvocation.MyCommand.Path
        }
        else {
            throw 'Unable to determine script path'
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
    }
}

function Get-DryPlatform {
    [CmdletBinding()]
    param (
        $ScriptPath
    )
    try {
        $PSPlatform = & { switch ($PSVersionTable.Platform) { $null {return 'Win32NT'} default {return $PSVersionTable.Platform }}}
        $Platform = [PSObject]@{
            Edition                 = $PSversionTable.PSEdition
            Version                 = $PSversionTable.PSVersion.ToString()
            Platform                = $PSPlatform
            Home                    = & {switch ($PSPlatform) {'Win32NT' {return "$($env:UserProfile)" } 'Unix' {return "$($env:HOME)" }}}
            Slash                   = & {switch ($PSPlatform) {'Win32NT' {return '\'} 'Unix' {return '/'}}}
            Separator               = & {switch ($PSPlatform) {'Win32NT' {return ';'} 'Unix' {return ':'}}}
            LocalModulesDirectories = @(
                ([IO.Path]::GetFullPath("$(Join-Path -Path $ScriptPath -ChildPath 'modules')")),
                ([IO.Path]::GetFullPath("$(Join-Path -Path $ScriptPath -ChildPath 'actions')"))
            )
            RootWorkingDirectory    =  & {switch ($PSPlatform) {
                'Win32NT' {return (Join-Path -Path "$($env:UserProfile)" -ChildPath 'DryDeploy')} 
                'Unix' {return (Join-Path -Path "$($env:HOME)" -ChildPath 'DryDeploy')}}
            }   
        }
        return $Platform
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
    }
}

function Set-DryPSModulePath {
    [CmdletBinding()]
    param (
        [PSObject]$Platform
    )
    try {
        foreach ($LocalModulesDirectory in $Platform.LocalModulesDirectories) {
            switch ($Platform.Platform) {
                'Win32NT' {
                    if ($env:PSModulePath -notmatch ($LocalModulesDirectory -replace'\\','\\')) {
                        $env:PSModulePath = "$($env:PSModulePath);$LocalModulesDirectory" 
                    }
                }
                'Unix' {
                    if ($env:PSModulePath -notmatch $LocalModulesDirectory) {
                        $env:PSModulePath = "$($env:PSModulePath):$LocalModulesDirectory" 
                    }
                }
                default {
                    throw "Platform unknown: $($Platform.Platform). DD runs on Windows and Linux only"
                }
            }
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
    }
}
#endregion PreModulesFunctions

try {
    if ($ShowAllErrors) {$Error.clear()}
    $dry_var_OriginalPSModulePath                     = $env:PSModulePath #to be set back in finally
    $GLOBAL:dry_var_global_ScriptPath                 = Get-DryScriptPath
    $GLOBAL:dry_var_global_Platform                   = Get-DryPlatform -ScriptPath $GLOBAL:dry_var_global_ScriptPath
    Set-DryPSModulePath -Platform $GLOBAL:dry_var_global_Platform
    
    # Remove DD modules that may have escaped the removal in finally{}
    Get-Module | Where-Object {(
        ($_.Name -match "^dry\.module\.") -or 
        ($_.Name -match "^dry\.action\.")
    )} | Remove-Module -Force -ErrorAction Stop

    $GLOBAL:dry_var_global_ShowStatus                 = $ShowStatus
    $GLOBAL:dry_var_global_SuppressInteractivePrompts = $SuppressInteractivePrompts
    $GLOBAL:dry_var_global_Force                      = $Force
    $GLOBAL:dry_var_global_ShowPasswords              = $ShowPasswords
    $GLOBAL:dry_var_global_KeepConfigFiles            = $KeepConfigFiles
    $GLOBAL:dry_var_global_WarnOnTooNarrowConsole     = $true #! lagt i options som 'warn_on_too_narrow_console'
    $GLOBAL:dry_var_global_RootWorkingDirectory       = $dry_var_global_Platform.RootWorkingDirectory
     
    
    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        Get the current global preference values, so they can be set back in finally. Set global 
        preferences, so -Verbose and -Debug works down the stack (in every function in every 
        module called by DD). In general, using -debug sets $DebugPreference to 'Inquire' - that 
        is mighty impractical. Rather, let it continue, and display the debug log items. When
        we want to inquire, we make a breakpoint in vscode.
    
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
    $SCRIPT:dry_var_GlobalVerbosePreference      = $GLOBAL:VerbosePreference 
    $SCRIPT:dry_var_GlobalDebugPreference        = $GLOBAL:DebugPreference
    $SCRIPT:dry_var_GlobalErrorActionPreference  = $GLOBAL:ErrorActionPreference
    $GLOBAL:VerbosePreference             = $PSCmdlet.GetVariableValue('VerbosePreference')
    $GLOBAL:DebugPreference               = $PSCmdlet.GetVariableValue('DebugPreference')
    $GLOBAL:ErrorActionPreference         = 'Stop'
    if ($GLOBAL:DebugPreference -eq 'Inquire') { 
        $GLOBAL:DebugPreference           = 'Continue' 
        $SCRIPT:DebugPreference           = 'Continue'
    }

    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        Define som paths
    
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
    [String]$dry_var_PlanFile           = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'dry_deploy_plan.json'
    [String]$dry_var_ResourcesFile      = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'dry_deploy_resources.json'
    [String]$dry_var_ConfigComboFile    = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'dry_deploy_config_combo.json'
    [String]$dry_var_UserOptionsFile    = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'UserOptions.json' # the user may create this file to override the defaults
    [String]$dry_var_TempConfigsDir     = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'TempConfigs'
    [String]$dry_var_LogsArchiveDir     = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'ArchivedLogs'
    [String]$dry_var_SystemOptionsFile  = Join-Path -Path $dry_var_global_ScriptPath           -ChildPath 'SystemOptions.json'
    [String]$GLOBAL:dry_var_global_CredentialsFile    = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'dry_deploy_credentials.json'
    
    New-DryItem -ItemType Directory -Items @($dry_var_global_RootWorkingDirectory, $dry_var_LogsArchiveDir, $dry_var_TempConfigsDir)
    
   
    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        System options are options defined in SystemOptions.json at root of DD, while user 
        options is an optional file UserOptions.json at root of the working directory 
        $dry_var_global_RootWorkingDirectory. Any UserOption overrides the SystemOptions
    
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
    $dry_var_SystemOptions = Get-DryFromJson -Path $dry_var_SystemOptionsFile
    $dry_var_UserOptions   = Get-DryFromJson -MaybePath $dry_var_UserOptionsFile

    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        Set options for logging and the format of how messages are displayed on 
        the console. The function defines default options, that may be overridden
        by the system options, that may be overridden user options. The function
        Out-DryLog of 'dry.module.log' will test for the variable LoggingOptions
        in the global scope and use those options if they exist. If not, the 
        function's own set of defaults are used 

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
    $SetDryLoggingOptionsParams = @{
        SystemConfig     = $dry_var_SystemOptions.logging 
        UserConfig       = $dry_var_UserOptions.logging
        WorkingDirectory = $dry_var_global_RootWorkingDirectory
        ArchiveDirectory = $dry_var_LogsArchiveDir
        NoLog            = $NoLog
    }
    Set-DryLoggingOptions @SetDryLoggingOptionsParams
    $SetDryLoggingOptionsParams = $null
    

    # Greet our gullible minions
    ol i "DryDeploy $($PSCmdLet.ParameterSetName): intro" -sh -air
    ol i ' '

    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        The ConfigCombo is a mapping between an EnvConfig and a ModuleConfig. The object stores 
        paths to those configurations, and will reuse the already stored values each time you 
        -Init, -Plan or -Apply. You modify the ConfigCombo by specifying -EnvConfig or 
        -ModuleConfig (invoking the parameterset 'SetConfig')

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
    $GetDryConfigComboParams = @{
        Path          = $dry_var_ConfigComboFile 
        Platform      = $GLOBAL:dry_var_global_Platform
        SystemOptions = $dry_var_SystemOptions
    }
    $GLOBAL:dry_var_global_ConfigCombo = Get-DryConfigCombo @GetDryConfigComboParams
    $GetDryConfigComboParams = $null
    
    switch ($PSCmdLet.ParameterSetName) {
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            Parameterset: Init
        
            Installs dependencies for DD, your EnvConfig, and your ModuleConfig. DD has 
            some dependencies spesified on SystemOptions.json at root. Your selected EnvConfig and 
            ModuleConfig may each have theirs in their 'Config.json' at root of each repo, in a 
            "dependencies": {} object. You must elevate Powershell and run .\DryDeploy.ps1 -Init 
            at least once for a configuration combination.

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        'Init' {
            #! All of this must be changed when dry.module.pkgmgmt is released
            #! The test-dryelevated should only be run if there are changes to be made
            if (Test-DryElevated){
                # System Dependencies
                if ($dry_var_global_ConfigCombo.TestDepHash('system')) {
                    ol i "System dependencies already met"
                } 
                else {
                    ol i "System dependencies must be installed" -sh
                    Install-DryDependencies -ConfigCombo $dry_var_global_ConfigCombo -Type 'system'
                }
                    
                # Module Dependencies
                if ($null -ne $dry_var_global_ConfigCombo.moduleconfig.path) {
                    if ($null -ne $dry_var_global_ConfigCombo.moduleconfig.dependencies) {
                        if ($dry_var_global_ConfigCombo.TestDepHash('module')) {
                            ol i "ModuleConfig dependencies already met"
                        } 
                        else {
                            ol i "ModuleConfig dependencies must be installed" -sh
                            Install-DryDependencies -ConfigCombo $dry_var_global_ConfigCombo -Type 'module'
                        }
                    }                
                }
                else {
                    ol w "Run -Init also after you have selected a ModuleConfig"
                }

                # Environment dependencies
                if ($null -ne $dry_var_global_ConfigCombo.envconfig.path){
                    if ($null -ne $dry_var_global_ConfigCombo.envconfig.dependencies) {
                        if ($dry_var_global_ConfigCombo.TestDepHash('environment')) {
                            ol i "EnvConfig dependencies already met"
                        } 
                        else {
                            ol i "EnvConfig dependencies must be installed" -sh
                            Install-DryDependencies -ConfigCombo $dry_var_global_ConfigCombo -Type 'environment'
                        } 
                    }               
                }
                else {
                    ol w "Run -Init also after you have selected an EnvConfig"
                }
            }
            else {
                throw "Init requires PowerShell to run elevated ('Run as Administrator')"
            }
        }
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            
            Parameterset: SetConfig
            
            Invoked if you -EnvConfig and/or -ModuleConfig. It sets (or modifies) the 'ConfigCombo'. 
            The ConfigCombo is an object containing paths to (and some more info of) your current
            selections of environment (-EnvConfig) and module (-ModuleConfig). SetConfig verifies 
            your selection(s), and stores them in a file. The next time you DD, that file
            will be picked up, read, and all work will be done against that combination, until you 
            make a change by invoking SetConfig again. This way, you don't have to specifiy what 
            environment to deploy to, and what module to depoloy, every time you DD. 
            
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        'SetConfig' {
            
            if ($EnvConfig) {
                $dry_var_global_ConfigCombo.change($EnvConfig,'environment')    
            }
            if ($ModuleConfig) {
                $dry_var_global_ConfigCombo.change($ModuleConfig,'module')
            }
            $dry_var_global_ConfigCombo.show()      
        }
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            
            Parameterset: ShowPlan
            
            Shows the state of the current Plan.

            ShowPlan is an inferiour, mundane parameterset for lesser mortals. It's like having to 
            physically move the piece on a chess board in other realise what option the opponent has. 
            In other words, it's for me...  
            
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        'ShowPlan' {
            
            $dry_var_global_ConfigCombo.show()
            
            $GetDryPlanParams = @{
                PlanFile             = $dry_var_PlanFile
                ResourceNames        = $Resources
                ExcludeResourceNames = $ExcludeResources
                ActionNames          = $Actions
                ExcludeActionNames   = $ExcludeActions
                BuildSteps          = $BuildSteps
                ExcludeBuildSteps   = $ExcludeBuildSteps
                Phases               = $Phases
                ExcludePhases        = $ExcludePhases
                ShowStatus           = $True
            }
            $PlanObj = Get-DryPlan @GetDryPlanParams -ErrorAction Stop
            $GetDryPlanParams = $null
            
            
            # $PlanObj.Show('Plan',$ShowDeselected,$ShowConfigCombo,$dry_var_global_ConfigCombo)
    
            $ShowDryPlanParams       = @{
                Plan                 = $PlanObj
                Mode                 = 'Plan' 
                ConfigCombo          = $dry_var_global_ConfigCombo 
                ShowConfigCombo      = $True
                ShowDeselected       = $ShowDeselected
            }
            #! Show-DryPlan bør kanskje bli $PlanObj.show()
            Show-DryPlan @ShowDryPlanParams
            $ShowDryPlanParams = $null

        }
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            
            Parameterset: Plan, Apply, GetConfig
            
            Common procedures for a bunch of parametersets. Gets configurations in the ComfigCombo, 
            gets and invokes common variables, prepares for credentials.
            
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        {$_ -in 'Plan','Apply','GetConfig'} {
            $GLOBAL:dry_var_global_Configuration = Get-DryEnvConfig -ConfigCombo $dry_var_global_ConfigCombo
            $GLOBAL:dry_var_global_Configuration = Get-DryModuleConfig -ConfigCombo $dry_var_global_ConfigCombo -Configuration $GLOBAL:dry_var_global_Configuration 
            <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            
                Common Variables
                
                $dry_var_CommonVariables are processed once per run (if you, -Plan, -Apply or -GetConfig), 
                as opposed to $dry_var_ResourceVariables, that are processed once per resource, hence 
                resource specific

            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>

            if ($GLOBAL:dry_var_global_Configuration.common_variables) {
                $dry_var_CommonVariables = Resolve-DryVariables -Variables $GLOBAL:dry_var_global_Configuration.common_variables -Configuration $GLOBAL:dry_var_global_Configuration -OutputType 'list'
                $dry_var_CommonVariables.foreach({
                    if (Get-Variable -Name $_.Name -Scope GLOBAL -ErrorAction Ignore) {
                        Set-Variable -Name $_.Name -Value $_.Value -Scope GLOBAL
                    }
                    else {
                        New-Variable -Name $_.Name -Value $_.Value -Scope GLOBAL
                    }
                }) 
            }
            # Replace any common ReplacementPattern ("###($Variable.name)###") in $Configuration
            $GLOBAL:dry_var_global_Configuration = Resolve-DryReplacementPatterns -InputObject $GLOBAL:dry_var_global_Configuration -Variables $dry_var_CommonVariables

            <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            
                Credentials File
                
                The EnvConfig and/or ModuleConfig may provide placeholders for Credentials that should 
                be put in a local credentials file. Actions contain a cedentials node that specifies
                only an 'Alias' to a credential, however, that Alias may be specified with a UserName
                and other properties in the EnvConfig or ModuleConfig. 
                
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
            New-DryCredentialsFile -Path $dry_var_global_CredentialsFile

            #! currently only support for 'encryptedstring', should support 'HashicorpVault'++
            if (-not $GLOBAL:dry_var_global_Configuration.CredentialsType) {
                $GLOBAL:dry_var_global_Configuration | Add-Member -MemberType NoteProperty -Name 'CredentialsType' -Value 'encryptedstring'
            }
            
            if ($GLOBAL:dry_var_global_Configuration.Credentials) {
                foreach ($Credential in $GLOBAL:dry_var_global_Configuration.Credentials) {
                    $AddCredentialPlaceholderParams = @{
                        Alias        = $Credential.Alias
                        EnvConfig    = $dry_var_global_ConfigCombo.envconfig.name
                        Type         = $GLOBAL:dry_var_global_Configuration.CredentialsType
                    }
                    if ($Credential.UserName) {
                        $AddCredentialPlaceholderParams += @{
                            UserName = $Credential.UserName
                        }
                    }
                    Add-DryCredentialPlaceholder @AddCredentialPlaceholderParams
                }
                $AddCredentialPlaceholderParams = $null
            }
            
            if ($GetConfig) {
                return $GLOBAL:dry_var_global_Configuration
            }
        }
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            
            Parameterset: Plan
            
            Plan archives any existing plan, and creates a new plan for all Resources in the build, 
            filtering away any unwanted Resources or Actions. Plan allows you to see what you're
            about to build, before you actually -Apply.  
            
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        'Plan' {
            $NewDryPlanParams = @{
                ResourcesFile        = $dry_var_ResourcesFile
                PlanFile             = $dry_var_PlanFile
                Configuration        = $dry_var_global_Configuration
                CommonVariables      = $dry_var_CommonVariables
                ResourceNames        = $Resources
                ExcludeResourceNames = $ExcludeResources
                ActionNames          = $Actions
                ExcludeActionNames   = $ExcludeActions
                BuildSteps          = $BuildSteps
                ExcludeBuildSteps   = $ExcludeBuildSteps
                Phases               = $Phases
                ExcludePhases        = $ExcludePhases
            }
            $dry_var_PlanObj = New-DryPlan @NewDryPlanParams
            $NewDryPlanParams = $null
            
            $ShowDryPlanParams = @{
                Plan                 = $dry_var_PlanObj
                Mode                 = 'Plan' 
                ConfigCombo          = $dry_var_global_ConfigCombo 
                ShowConfigCombo      = $True
                ShowDeselected       = $ShowDeselected
            }
            Show-DryPlan @ShowDryPlanParams
            $dry_var_PlanObj = $null
            $ShowDryPlanParams = $null
        }
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            
            Parameterset: Apply
            
            Apply gets the current plan, and executes actions in the correct order. If retrying from 
            a previously failed attempt, it retries the failed Action and continues from there, if, 
            this time, it succeeds
            
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        'Apply' {
            $GetDryPlanParams = @{
                PlanFile             = $dry_var_PlanFile
                ResourceNames        = $Resources
                ExcludeResourceNames = $ExcludeResources
                ActionNames          = $Actions
                ExcludeActionNames   = $ExcludeActions
                BuildSteps          = $BuildSteps
                ExcludeBuildSteps   = $ExcludeBuildSteps
                Phases               = $Phases
                ExcludePhases        = $ExcludePhases
            }
            $dry_var_PlanObj           = Get-DryPlan @GetDryPlanParams -ErrorAction Stop
            $dry_var_ResolvedResources = Get-DryFromJson -Path $dry_var_ResourcesFile -ErrorAction Stop
            $GetDryPlanParams          = $null

            <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            
                The ConfigCombo will store hashes of all dependencies when you elevate Powershell and 
                successfully run .\DryDeploy -Init. Once done, the tests below will pass on every 
                subsequent run, until you change the configuration by -ModuleConfig and/or -EnvConfig. If 
                you want to ignore that, since you know best, don't you? You may -IgnoreDependencies, 
                upon which I will only display a warning. 
                
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
            if (($dry_var_global_ConfigCombo.TestDepHash('system')) -and
                ($dry_var_global_ConfigCombo.TestDepHash('environment')) -and
                ($dry_var_global_ConfigCombo.TestDepHash('module'))) {
                if ($IgnoreDependencies) {
                    ol w "The ConfigCombo seems to require -Init, but continuing due to -IgnoreDependencies"
                }
                else {
                    ol w "The ConfigCombo requires -Init. Elevate Powershell, and run '.\DryDeploy.ps -Init' once. If you disagree, you may -IgnoreDependencies"
                    throw 'The ConfigCombo requires -Init'
                }
            }
            
            <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            
                The iteration on every object in the Plan.  
                
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
            for ($ActionCount = 1; $ActionCount -le $dry_var_PlanObj.ActiveActions; $ActionCount++ ) {
                $Action = $null
                $Action = $dry_var_PlanObj.Actions | Where-Object { $_.ApplyOrder -eq $ActionCount }
                
                if ($Null -eq $Action) { throw "Unable to find Action with Order $ActionCount in Plan" }

                try {
                    if ($Action.Status -eq 'Todo') {
                        $Action.Status = 'Starting'
                        $dry_var_PlanObj.SaveToFile($dry_var_PlanFile,$False)
                    }
                    elseif ($Action.Status -eq 'Failed') {
                        $Action.Status = 'Retrying'
                        $dry_var_PlanObj.SaveToFile($dry_var_PlanFile,$False)
                    }
                    
                    Show-DryPlan -Plan $dry_var_PlanObj -Mode 'Apply' -ConfigCombo $dry_var_global_ConfigCombo
                    Show-DryActionStart -Action $Action

                    # Define the global resource name used in output after the plan has been shown
                    New-Variable -Name GlobalResourceName -Value $Action.ResourceName -Scope GLOBAL -Force
                    New-Variable -Name GlobalActionName -Value $Action.Action -Scope GLOBAL -Force
                    if ($Action.Phase -ge 1) {
                        New-Variable -Name GlobalPhase -Value $Action.Phase -Scope GLOBAL -Force
                    }
                    else {
                        Remove-Variable -Name GlobalPhase -Scope GLOBAL -ErrorAction Ignore -Force
                    }

                    # Match up this action with the resource object in $dry_var_ResolvedResources
                    Remove-Variable -Name Resource -ErrorAction Ignore 
                    $Resource = $dry_var_ResolvedResources.Resources | Where-Object { 
                        $_.Resource_Guid -eq $Action.Resource_Guid
                    }

                    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                    
                        Resource Variables
                        
                        $dry_var_global_ResourceVariables are invoked for each action, so they may contain 
                        values specific to the Resource (or Action, actually)

                    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                    if ($dry_var_global_Configuration.resource_variables) {
                        $ResolveDryVariablesParams = @{
                            Variables              = $dry_var_global_Configuration.resource_variables
                            Configuration          = $dry_var_global_Configuration
                            VariablesList          = $dry_var_CommonVariables
                            Resource               = $Resource
                            OutputType             = 'list'
                        }
                        $ResourceVariables = Resolve-DryVariables @ResolveDryVariablesParams
                        $ResolveDryVariablesParams = $null  
                    }

                    # Assume the worst
                    $Action.Status = 'Failed'
                    $ActionName = "dry.action.$($Action.Action)"
                    ol i @('Action Module/Name',"$ActionName")
                    $ActionName | Import-Module -Force -ErrorAction Stop

                    $ActionParameters     = @{
                        Action            = $Action 
                        Resource          = $Resource
                        Configuration     = $dry_var_global_Configuration
                        ResourceVariables = $ResourceVariables
                    }
                    
                    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                    
                        You may call ".\DryDeploy.ps1 -Apply -ActionParams @{'param1'='value1'}" to pass a hashtable
                        of names and values to the action-function if it supports some way of filtering on certain 
                        parts of the configuration, however this params are highly Action specific, som the action
                        function will automatically quit after this.

                    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                    if ($ActionParams) {
                        $ActionParameters+=@{'ActionParams'=$ActionParams}
                        $Quit = $true
                    }

                    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                        Execute Action
                    
                        This is where the Action Function get's called

                    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                    $ActionStartTime = Get-Date
                    & $ActionName @ActionParameters
                    $ActionEndTime = Get-Date
                    # No Catch?  
                    $Action.Status = 'Success'

                    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                        Quit

                        You may call 
                            .\DryDeploy.ps1 -Apply -Quit
                        to make DD quit after every action. That way, you can ensure it continues only
                        one Action at every run. Moreover, the -Quit parameter is nice for pipelines, since you 
                        may devide the pipeline into blocks. If Jenkins, or DevOpsServer, or Gitlab Automation, 
                        don't pick up the fail, DD will ensure all subsequent runs fail as well. 

                    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                    if ($Quit) {
                        $Error.Clear()
                        $LASTEXITCODE = 0
                        break
                    }

                    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                        Step
                    
                        You may call 
                            .\DryDeploy.ps1 -Apply -Step
                        to make DD wait for you to press ENTER to continue to the next Actions, or q/quit to 
                        just quit, if you're unhappy about something. You probably are, but don't push it

                    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                    if ($Step) {
                        $StepResponse = Read-Host -Prompt "Press ENTER to continue or Q(uit) to quit"
                        if (($StepResponse -eq 'q') -or ($StepResponse -eq 'quit')) { 
                            break
                        }
                    }
                }
                catch {
                    $Action.Status = 'Failed'
                    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                        On certain exceptions it may be pertinent to see the chain of errors in the stack. If
                        you call 
                            .\DryDeploy -Apply -ShowAllErrors
                        DD will show all elements in the $Error automatic variable using $Error | fl * -force 
                        
                        The -force is essential, as PowerShell, as most MS-products, like Russia, will try to 
                        decide what you want and won't. DryDeploy is a pro-Ukraina project. DD supports all 
                        Ukrainain refugees anywhere. 

                    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                    if ($ShowAllErrors) {
                        for ($ec = ($Error.count-1); $ec -ge 0; $ec--) {
                            if ($ec -eq 0) {
                                ol i "The terminating exception: " -sh
                                ol i " "
                            }
                            else {
                                ol i "Previous exception $ec`:" -sh
                                ol i " "
                            }
                            if ($Error[$ec].GetType().Name -eq 'ErrorRecord') {
                                Show-DryError -Err $Error[$ec]
                            }
                            else {
                                ol i "Not Error, type is: $($Error[$ec].GetType().Name)"
                            }
                        }
                    }
                    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                        Just show the terminating exception

                    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                    else {
                        ol i "The terminating exception: " -sh
                        ol i " "
                        Show-DryError -Err $_
                    }

                    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                        If we reach a catch, create a warning on the DD Action, but throw the original exception

                    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                    $dry_var_WarningString = "Failed action: [$($Action.action)]"
                    if ($Action.Phase) {
                        $dry_var_WarningString += " - Phase [$($Action.Phase)]"
                    }
                    ol w $dry_var_WarningString
                    $PSCmdLet.ThrowTerminatingError($_)
                }
                finally {
                    $dry_var_PlanObj.SaveToFile($dry_var_PlanFile,$False)
                    $ActionEndTime = Get-Date
                    $GLOBAL:GlobalResourceName = $null 
                    $GLOBAL:GlobalActionName = $null
                    $GLOBAL:GlobalPhase = $null
                    Remove-Module -Name "dry.action.$($Action.Action)" -ErrorAction Ignore
                    Show-DryActionEnd -Action $Action -StartTime $ActionStartTime -EndTime $ActionEndTime
                }
            }
        }
    }
}
catch {
    $PSCmdlet.ThrowTerminatingError($_)
}
finally {
    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        Reset DD's global Action-specific variables

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
    $GLOBAL:GlobalResourceName = $null 
    $GLOBAL:GlobalActionName = $null
    $GLOBAL:GlobalPhase = $null
    
    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        Reset Powershell's Global Preference variables

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
    $GLOBAL:VerbosePreference = $dry_var_GlobalVerbosePreference
    $GLOBAL:DebugPreference = $dry_var_GlobalDebugPreference
    $GLOBAL:ErrorActionPreference = $dry_var_GlobalErrorActionPreference

    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        Reset $PSModulePath

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
    $env:PSModulePath = $dry_var_OriginalPSModulePath
    
    ol i "DryDeploy $($PSCmdLet.ParameterSetName): outro" -sh -air
    ol i ' '

    
    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        Remove all DD-specific modules

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
    foreach ($DryModule in  @((Get-Module | 
        Where-Object { (($_.Name -match "^dry\.action\.") -or ($_.Name -match "^dry\.module\."))}) | 
        Select-Object Name).Name) {
        Get-Module $DryModule | Remove-Module -Verbose:$False -Force -ErrorAction Ignore
    }

    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        Remove all Common Variables from both the GLOBAL and LOCAL scope

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
    $dry_var_CommonVariables.foreach({
        if (Get-Variable -Name $_.Name -Scope GLOBAL -ErrorAction Ignore) {
            Remove-Variable -Name $_.Name -Scope GLOBAL
        }
        if (Get-Variable -Name $_.Name -Scope LOCAL -ErrorAction Ignore) {
            Remove-Variable -Name $_.Name -Scope LOCAL
        }
    })

    <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        Remove any variable in the GLOBAL and LOCAL scope that may remain

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
    (Get-Variable -Scope GLOBAL | Where-Object {$_.Name -match "^dry_var_"}) | ForEach-Object  { 
        Remove-Variable -Name "$_" -Scope Global -ErrorAction 'Ignore'
    }
    (Get-Variable -Scope LOCAL | Where-Object {$_.Name -match "^dry_var_"}) | ForEach-Object  { 
        Remove-Variable -Name "$_" -Scope Local -ErrorAction 'Ignore'
    }
}