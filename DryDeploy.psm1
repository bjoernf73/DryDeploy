<#
.SYNOPSIS
DryDeploy is a promiscuous deployment orchestrator - swinging among 
available orchestration and configuration technologies. 

A full autodeploy of an information system may require you to use 
a variety of orchestration and configuration technologies. For 
instance, terraform is great for configuring cloud platforms and 
instantiate resources, but it's inside-OS-capabilities are bad to 
say the least. Traditional DSC (Desired State Configuration) is great 
for configuring Windows roles, but does nothing for your platform 
provider. You may want to use packer to automate creation of templates
for your platform, and saltstack to manage packages within OS's - and 
so on.  

Common for DSC, terraform, packer, ansible, saltstack etc. is that: 
 - you create one or more files containing your configuration, using
 variables for environment specific values and secrets
 - when you deploy, you supply the tool with the path to the config 
 and all the variables that it needs.

At the core of DryDeploy lies the separation between 
 - ModuleConfig (the configuration files of a system or a range
   of systems)
 - EnvConfig (that defines the environment into which you will 
   deploy your system modules).

DryDeploy combines a ModuleConfig, which defines all details of how
to bring one or multiple roles (resource templates) into a ready to 
use state, with an EnvConfig, which contain all environment specific
variable values. Separate properly, and you may deploy otherwise 
identical instances of service and systems, spanning multiple servers 
and containers, into a dev (3), a test(2), a ref(1), and a production(0) 
environment with only a click of a button.

This separation between system modules and environment is key to proper 
automation, although misunderstood or ignored by most IT departments.
Most companies, state- and governmental agencies, are shockingly incapable 
of reproducing their services configurations, because of years of mismanagement,
and the misunderstanding of IAC. IAC is not making a script here and there. 
When you automate, you should be able to test your code in a separate, non-
critical environment which you may never be blamed for destroying by running 
a faulty config on. When your config finally works, it should be a no effort 
task to move on to the next environment (one closer to production). In DryDeploy,
you run a simple command to select the environment (EnvConfig) and the system 
module (ModuleConfig) you'd like to deploy, then you -Plan, then you -Apply. 

PS C:\DryDeploy> DryDeploy -ModuleConfig .\Path\2\My\ModuleConfig -EnvConfig .\Path\2\My\Environment

PS C:\DryDeploy> DryDeploy -Plan

PS C:\DryDeploy> DryDeploy -Apply

Go shopping while DryDeploy works through your build. Want it in a pipeline? No 
problem - I'd recommend DevOps Server, but you may use Gitlab if you so fancy.

If something fails, edit your code, and -Apply again. DryDeploy retries the 
failed Action and continues to apply the rest of the plan.

During development, filter the plan only selecting the parts of the configuration
you want to test. 

.DESCRIPTION
DryDeploy prepares your deployment platform (-Init), stores paths to a 
configuration combination (ConfigCombo) of an environment configuration
(-EnvConfig) and a module configuration (-ModuleConfig). Create a Plan 
of Actions to execute (-Plan). Multiple include- and exclude-filters may
be used to create a partial Plan. You may evaluate and resolve all params 
passed to each Action in a Plan before you execute it (-Resolve), but they
will also resolve when you Apply the Plan (-Apply). Run DryDeploy without
parameters to show the status of the current Plan. 

Dryeploy needs 2 configuration repositories: 

 - EnvConfig: must contain the "CoreConfig" - information of your 
   environment; network information, target platforms (cloud, on-prem, 
   hybrid), and all the resources (instances of roles). It can also
   contain a "UserConfig" which is any data you can put in a json
   or yaml. Lastly, it may contain "BaseConfig", which contains shared,
   generic configurations which every (or selected) instances of an 
   operating system should invoke.  

 - ModuleConfig: contains Roles and a Build. Roles are the blueprint
   configurations of some type of resource, be it a Windows domain
   controller, an Ubuntu Gitlab Server, or simply a container instance.
   A module may contain one or multiple roles, and roles may be re-used 
   in multiple system modules (DryDeploy works at the filesystem level, 
   and it is recommended to add roles as git submodules in a ModuleConfig).
   A Role contain the configuration files used by any Action that the role build addresses. It also contain a
   set of expressions that when run against the EnvConfig, they resolve 
   the variable values that in turn will be passed to the technology 
   behind the Action (i.e. Terraform, Packer, DSC, SaltStack and so on)
   The Build defines how the module is built. It contains 
      1. the order in which Roles are deployed
      2. the order in which Actions of the Roles are deployed
   Actions of a role may 'depend on' Actions of other roles, so that 
   when you -Plan, the execution of the dependent Action is delayed 
   until after the action it depends on.
   
.PARAMETER Init
Inistializes the local system for package management, and installs 
all dependencies for DryDeploy and for the selected system module.
Supports git-repos-as-PowerShell-modules, chocolatey packages, nuget
modules, windows features, optional features and so on.

.PARAMETER Plan
Create or modify a Plan. Use alone for a full Plan, or with any 
filter to limit the Actions to include in the Plan (-Actions, 
-ExcludeActions, -BuildSteps, -ExcludeBuildSteps, -Resources, 
-ExcludeResources, -Roles, -ExcludeRoles, -Phases, -ExcludePhases) 

.PARAMETER Resolve
Runs through the Plan, resolving all credentials, variables 
and options, but does not actually invoke the action. Each 
Action in a Plan run against a target to which you need to
authenticate. That credential is generally the first credential,
'credential1'. An Action may require one or more additional 
credentials which are resolved by your Action variables 
expressions, 'credential2', 'credential3' and so on. Those 
credentials are specified in the Plan by Aliases, for instance
'local-admin' or 'domain-admin' or 'db-svc-user'. Run
DryDeploy -Resolve to resolve those Aliases into actual 
credentials before you -Apply. If you don't, you may be 
prompted at the beginning av each Action for which a credential
isn't yet resolved. Once resolved, the credential will be stored 
as encrypted securestrings in
$home\DryDeploy\dry_deploy_credentials.json

.PARAMETER Apply
Applies the Plan. Use alone to to Apply the full Plan, or with
any filter to only Apply a limited set of planned actions (-Actions, 
-ExcludeActions, -BuildSteps, -ExcludeBuildSteps, -Resources, 
-ExcludeResources, -Roles, -ExcludeRoles, -Phases, -ExcludePhases)

.PARAMETER Interactive
Starts DryDeploy in interactive mode, which has the effect that 
resources specified in an environment are ignored. Instead, a single
resource will be defined from interactive prompts, and a plan for 
that resource is created. You still need to have a module and an 
environment selected. You may only select to build a resource from
a role in the currently selected system module.  

.PARAMETER Actions
Array of one or more Actions to include. All others are excluded. 
If not specified, Actions are disregarded from the filter. Supports 
tab-completion and partial match ('ter' will match Action 'terra.run')

.PARAMETER ExcludeActions
Array of one or more Actions to exclude. All others are included. 
If not specified, Actions are disregarded from the filter.Supports 
tab-completion and partial match ('ter' will match Action 'terra.run')

.PARAMETER BuildSteps
Array of one or more BuildSteps to include. All others are 
excluded. If not specified, BuildSteps are disregarded from 
the filter. Specify as digits, or sets of digits, like 3 or 
3,4,5 or (3..5) for a range

.PARAMETER ExcludeBuildSteps
Array of one or more BuildSteps to exclude. All others are 
included. If not specified, BuildSteps are disregarded from 
the filter. Specify as digits, or sets of digits, like 3 or 
3,4,5 or (3..5) for a range

.PARAMETER Resources
Array of one or more Resource names to include. All others are 
excluded. If not specified, Resources are disregarded from the 
filter. Supports tab-completion and partial match ('dc' will 
match Resource 'dc1-s5-d')

.PARAMETER ExcludeResources
Array of one or more Resource names to exclude. All others are 
included. If not specified, Resources are disregarded from the 
filter. Supports partial match ('dc' will match Resource 'dc1-s5-d')

.PARAMETER Roles
Array of one or more Role names to include. All others are 
excluded. If not specified, Roles are disregarded from the 
filter. Supports tab-completion and partial match ('dc' will 
match Role 'dc-domctrl-froot')

.PARAMETER ExcludeRoles
Array of one or more Role names to exclude. All others are 
included. If not specified, Roles are disregarded from the 
filter. Supports tab-completion and partial match ('dc' will 
match Role 'dc-domctrl-froot')

.PARAMETER Phases
Array of one or more Phases (of any Action) to include. All other 
Phases (and non-phased actions) are excluded. If not specified, 
Phases are disregarded from the filter

.PARAMETER ExcludePhases
Array of one or more Phases (of any Action) to exclude. All other 
Phases (and non-phased actions) are included. If not specified, 
Phases are disregarded from the filter

.PARAMETER EnvConfig
Path to the directory of an environment configuration. Use to  
set the configuration combination (ConfigCombo). It will be 
stored, and used implicitly until you change it. 

.PARAMETER ModuleConfig
Path to the directory of a system module configuration. Use to 
set the configuration combination (ConfigCombo). It will be 
stored, and used implicitly until you change it. 

.PARAMETER ActionParams
HashTable that will be sent to the Action function. Useful during 
development, for instance if the receiving action function 
supports a parameter to specify a limited set of tasks to do. 

.PARAMETER GetConfig
During -Plan and -Apply, selected configurations from the current 
Environment and Module are combined into one configuration object.
Run -GetConfig to just return this configuration object, and then 
quit. Assign the output to a variable to examine the configuration.

.PARAMETER GitHub
Launches the DryDeploy Github page in your favouritemost browser.

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

.PARAMETER Rewind
In an existing plan, rewinds one buildstep. That is, searches 
for the first occurance of a buildstep with status 'todo', and
sets status 'todo' on the action just before it in the current
plan. Will only work when you Apply a continuous plan - not if 
you have applied random steps here and there.

.PARAMETER FastFwd
In an existing plan, fastforwards one buildstep. That is, 
searches for the first occurance of a buildstep with a status 
that is not 'Success', and sets that Action's status to 
'Success' so DryDeploy perceives it as applied. 

.PARAMETER CMTrace
Will open the log file in cmtrace som you may follow the output-
to-log interactively. You will need CMTrace.exe on you system 
and in path 

.PARAMETER Force
Will destroy existing resources. Careful.

.EXAMPLE
DryDeploy -Init
Will prepare your system for deployment. Installs Choco, Git, 
Packer, downloads and installs modules, and dependent git repos.
Make sure to elevate your PowerShell for this one - it will fail
if not

.EXAMPLE
DryDeploy -ModuleConfig ..\ModuleConfigs\MyModule -EnvConfig ..\EnvConfigs\MyEnvironment
Creates a configuration combination of a module configuration and
an environment configuration. The combination (the "ConfigCombo") 
is stored and used on every subsequent run until you invoke the 
SetConfig parameterset again.

.EXAMPLE
DryDeploy -Plan
Will create a full plan for all resources in the configuration that
is of a role that matches roles in your ModuleConfig

.EXAMPLE
DryDeploy
Displays the current Plan

.EXAMPLE
DryDeploy -Plan -Resources dc,ca
Creates a partial plan, containing only Resources whos name is 
or matches "dc*" or "ca*"

.EXAMPLE
DryDeploy -Plan -Resources dc,ca -Actions terra,ad
Creates a partial plan, containing only Resources whos name is 
or match "dc*" or "ca*", with only Actions whos name is or 
matches "terra*" (for instance "terra.run") or "ad*" (for instance 
"ad.import")

.EXAMPLE
DryDeploy -Plan -ExcludeResources DC,DB
Creates a partial plan, excluding any Resource whos name is or 
matches "DC*" or "DB*"

.EXAMPLE
DryDeploy -Resolve
Resolves all credentials, variables and options for each Action 
in the current plan, but does not actually invoke the Action

.EXAMPLE
DryDeploy -Apply
Applies the current Plan. 

.EXAMPLE
DryDeploy -Apply -Force
Applies the current Plan, destroying any resource with the same 
identity as the resource you are creating. 

.EXAMPLE
DryDeploy -Apply -Resources ca002 -Actions ad.import
Applies only actions of the Plan where the Resources name is or 
matches "ca002*", and the name of the Action that is or matches 
"ad.import"

.EXAMPLE
$Config = DryDeploy -GetConfig
Returns the configuration object, and assigns it to the variable 
'$Config' so you may inspect it's content 'offline' 
#>
function DryDeploy {
    [CmdLetBinding(DefaultParameterSetName='ShowPlan')]
    [Alias("dd")]
    param ( 
        [Parameter(ParameterSetName='Github',
        HelpMessage='Launches the DryDeploy Github page in your 
        favouritemost browser')]
        [Switch]
        $GitHub,

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

        [Parameter(Mandatory,ParameterSetName='Resolve',
        HelpMessage='Resolves credentials, Action variables, and other
        options, but does not invoke the Action. Use to ensure all 
        variables can be resolved, and that all credentials are stored
        so you are not prompted for them during -Apply')]
        [Switch]
        $Resolve,

        [Parameter(Mandatory,ParameterSetName='Apply',
        HelpMessage="To start applying (performing actions) according 
        to plan. If you don't, I'll only plan.")]
        [Switch]
        $Apply,

        [Parameter(Mandatory,ParameterSetName='Interactive',
        HelpMessage="Starts DryDeploy in interactive mode, which has 
        the effect that resources specified in an environment are 
        ignored. Builds one resource only each time you run it.")]
        [Switch]
        $Interactive,

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
        [ArgumentCompleter({((Get-Content -Path (Join-Path -Path ((Get-Content -Path (Join-Path -Path (Join-Path -Path $home -ChildPath 'DryDeploy') -ChildPath 'dry_deploy_config_combo.json') | ConvertFrom-Json).envconfig.coreconfigpath) -ChildPath 'resources.json')) -replace '("(\\.|[^\\"])*")|/\*[\S\s]*?\*/|//.*', '$1' | ConvertFrom-Json).resources | Select-Object -ExpandProperty Name})]
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
        [ArgumentCompleter({((Get-Content -Path (Join-Path -Path ((Get-Content -Path (Join-Path -Path (Join-Path -Path $home -ChildPath 'DryDeploy') -ChildPath 'dry_deploy_config_combo.json') | ConvertFrom-Json).envconfig.coreconfigpath) -ChildPath 'resources.json')) -replace '("(\\.|[^\\"])*")|/\*[\S\s]*?\*/|//.*', '$1' | ConvertFrom-Json).resources | Select-Object -ExpandProperty Name})]
        [String[]]
        $ExcludeResources,

        [Parameter(ParameterSetName='Plan',
        HelpMessage='Array of one or more Role names to include. 
        All others are excluded. If not specified, all Roles are 
        included')]
        [Parameter(ParameterSetName='Apply',
        HelpMessage='Array of one or more Role names to include. 
        All others are excluded. If not specified, all Reles are 
        included')]
        [ArgumentCompleter({((Get-Content -Path (Join-Path -Path ((Get-Content -Path (Join-Path -Path (Join-Path -Path $home -ChildPath 'DryDeploy') -ChildPath 'dry_deploy_config_combo.json') | ConvertFrom-Json).envconfig.coreconfigpath) -ChildPath 'resources.json')) -replace '("(\\.|[^\\"])*")|/\*[\S\s]*?\*/|//.*', '$1' | ConvertFrom-Json).resources | Select-Object -ExpandProperty Role})]
        [String[]]
        $Roles,

        [Parameter(ParameterSetName='Plan',
        HelpMessage='Array of one or more Role names to exclude. 
        All others are included. If not specified, no Roles are 
        excluded')]
        [Parameter(ParameterSetName='Apply',
        HelpMessage='Array of one or more Role names to exclude. 
        All others are included. If not specified, no Roles are 
        excluded')]
        [ArgumentCompleter({((Get-Content -Path (Join-Path -Path ((Get-Content -Path (Join-Path -Path (Join-Path -Path $home -ChildPath 'DryDeploy') -ChildPath 'dry_deploy_config_combo.json') | ConvertFrom-Json).envconfig.coreconfigpath) -ChildPath 'resources.json')) -replace '("(\\.|[^\\"])*")|/\*[\S\s]*?\*/|//.*', '$1' | ConvertFrom-Json).resources | Select-Object -ExpandProperty Role})]
        [String[]]
        $ExcludeRoles,

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

        [Parameter(ParameterSetName='Rewind',
        HelpMessage='In an existing plan, rewinds one buildstep. That is, 
        the function searches for the first occurance of a buildstep with
        status ''todo'', and sets status = ''todo'' on the action just 
        before it')]
        [Switch]
        $Rewind,

        [Parameter(ParameterSetName='FastFwd',
        HelpMessage='In an existing plan, fastforwards one buildstep. That is, 
        the function searches for the first occurance of a buildstep with
        a status that is not ''Success'', and sets status = ''Success'' on
        that action')]
        [Switch]
        $FastFwd,

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
        finally {
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
        finally {
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
        $GLOBAL:dry_var_global_DestroyOnFailedBuild       = $DestroyOnFailedBuild
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
        $SCRIPT:dry_var_GlobalVerbosePreference     = $GLOBAL:VerbosePreference
        $SCRIPT:dry_var_GlobalDebugPreference       = $GLOBAL:DebugPreference
        $SCRIPT:dry_var_GlobalErrorActionPreference = $GLOBAL:ErrorActionPreference
        $GLOBAL:VerbosePreference                   = $PSCmdlet.GetVariableValue('VerbosePreference')
        $GLOBAL:DebugPreference                     = $PSCmdlet.GetVariableValue('DebugPreference')
        $GLOBAL:ErrorActionPreference               = 'Stop'
        if ($GLOBAL:DebugPreference -eq 'Inquire') { 
            $GLOBAL:DebugPreference = 'Continue'
            $SCRIPT:DebugPreference = 'Continue'
        }

        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            Define paths
        
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        [String]$dry_var_PlanFile           = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'dry_deploy_plan.json'
        [String]$dry_var_ResourcesFile      = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'dry_deploy_resources.json'
        [String]$dry_var_ConfigComboFile    = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'dry_deploy_config_combo.json'
        [String]$dry_var_UserOptionsFile    = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'UserOptions.json' # the user may create this file to override the defaults
        [String]$dry_var_TempConfigsDir     = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'TempConfigs'
        [String]$dry_var_ArchiveDir         = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'Archived'
        [String]$dry_var_SystemOptionsFile  = Join-Path -Path $dry_var_global_ScriptPath           -ChildPath 'SystemOptions.json'
        [String]$GLOBAL:dry_var_global_CredentialsFile    = Join-Path -Path $dry_var_global_RootWorkingDirectory -ChildPath 'dry_deploy_credentials.json'

        $dry_var_Paths = [PSCustomObject]@{
            RootWorkingDirectory = $dry_var_global_RootWorkingDirectory
            PlanFile             = $dry_var_PlanFile
            ResourcesFile        = $dry_var_ResourcesFile
            ConfigComboFile      = $dry_var_ConfigComboFile
            UserOptionsFile      = $dry_var_UserOptionsFile
            TempConfigsDir       = $dry_var_TempConfigsDir
            ArchiveDir           = $dry_var_ArchiveDir
            SystemOptionsFile    = $dry_var_SystemOptionsFile
        }
        
        New-DryItem -ItemType Directory -Items @($dry_var_global_RootWorkingDirectory, $dry_var_ArchiveDir, $dry_var_TempConfigsDir)
    
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
            ArchiveDirectory = $dry_var_ArchiveDir
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
        if ($EnvConfig) {
            $GetDryConfigComboParams += @{
                NewEnvConfig = $true
            }
        }
        if ($ModuleConfig) {
            $GetDryConfigComboParams += @{
                NewModuleConfig = $true
            }
        }
        $GLOBAL:dry_var_global_ConfigCombo = Get-DryConfigCombo @GetDryConfigComboParams
        $GetDryConfigComboParams = $null

        switch ($PSCmdLet.ParameterSetName) {
            'Interactive' {
                # -Interactive sets the interactive property to true, and will stay true until you -Plan
                $GLOBAL:dry_var_global_ConfigCombo.systemconfig.interactive = $true
            }
            'Plan' {
                # -Plan resets the interactive property back to false
                $GLOBAL:dry_var_global_ConfigCombo.systemconfig.interactive = $false
            }
        }
        $GLOBAL:dry_var_global_ConfigCombo.Save()
        
        switch ($PSCmdLet.ParameterSetName) {
            'GitHub' {
                Start-Process 'https://github.com/bjoernf73/DryDeploy' -Wait:$false
            }
            <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                Parameterset: Init
            
                Installs dependencies for DD, your EnvConfig, and your ModuleConfig. DD has 
                some dependencies spesified on SystemOptions.json at root. Your selected EnvConfig and 
                ModuleConfig may each have theirs in their 'Config.json' at root of each repo, in a 
                "dependencies": {} object. You must elevate Powershell and run DryDeploy -Init 
                at least once for a configuration combination.

            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
            #! INIT must be changed when dry.module.pkgmgmt is released
            #! The test-dryelevated should only be run if there are changes to be made
            'Init' {
                
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
                # ensure plan is removed when config changes
                if (Test-Path -Path $dry_var_PlanFile -ErrorAction Ignore) {
                    Remove-Item -Path $dry_var_PlanFile -Force | Out-Null
                }
                if ($EnvConfig) {
                    $dry_var_global_ConfigCombo.change($EnvConfig,'environment')    
                }
                if ($ModuleConfig) {
                    $dry_var_global_ConfigCombo.change($ModuleConfig,'module')
                }
                $dry_var_global_ConfigCombo.show()      
            }
            <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                
                Parameterset: ShowPlan, Rewind and FastFwd
                
                All Sets shows the state of the current Plan, however Rewind set's it back one buildstep, 
                and FastFwd one forward. 

                ShowPlan is an inferiour, mundane parameterset for lesser mortals. It's like having to 
                physically move pieces on a chess board to analyze the game. In other words, it's for 
                me... Prints out the status of the current Plan.   
                
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
            {$_ -in 'ShowPlan','Rewind', 'FastFwd'} {
                
                $dry_var_global_ConfigCombo.show()
                
                $GetDryPlanParams = @{
                    PlanFile             = $dry_var_PlanFile
                    ResourceNames        = $Resources
                    ExcludeResourceNames = $ExcludeResources
                    RoleNames            = $Roles
                    ExcludeRoleNames     = $ExcludeRoles
                    ActionNames          = $Actions
                    ExcludeActionNames   = $ExcludeActions
                    BuildSteps           = $BuildSteps
                    ExcludeBuildSteps    = $ExcludeBuildSteps
                    Phases               = $Phases
                    ExcludePhases        = $ExcludePhases
                    ShowStatus           = $true
                }
                $dry_var_Plan = Get-DryPlan @GetDryPlanParams -ErrorAction Stop
                $GetDryPlanParams = $null

                if ($PSCmdlet.ParameterSetName -eq 'Rewind') {
                    ol i "Rewinding one buildstep..."
                    $dry_var_Plan.RewindPlanOrder($dry_var_PlanFile)
                }
                elseif ($PSCmdlet.ParameterSetName -eq 'FastFwd') {
                    ol i "Fast-Forward one buildstep..."
                    $dry_var_plan.FastForwardPlanOrder($dry_var_PlanFile)
                }
                
                $ShowDryPlanParams       = @{
                    Plan                 = $dry_var_Plan
                    Mode                 = 'Plan' 
                    ConfigCombo          = $dry_var_global_ConfigCombo 
                    ShowConfigCombo      = $true
                    ShowDeselected       = $ShowDeselected
                }
                Show-DryPlan @ShowDryPlanParams
                $ShowDryPlanParams = $null
            }
            <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                
                Parameterset: Plan, Apply, GetConfig
                
                Common procedures for a bunch of parametersets. Gets configurations in the ComfigCombo, 
                gets and invokes common variables, prepares for credentials.
                
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
            {$_ -in 'Plan','Apply','GetConfig','Resolve','Interactive'} {
                $dry_var_Paths | Add-Member -MemberType NoteProperty -Name 'BaseConfigDirectory' -Value (Join-Path -Path $dry_var_global_ConfigCombo.envconfig.path -ChildPath 'BaseConfig')
                $dry_var_Paths | Add-Member -MemberType NoteProperty -Name 'ModuleConfigDirectory' -Value $dry_var_global_ConfigCombo.moduleconfig.path
                $GLOBAL:dry_var_global_Configuration = Get-DryEnvConfig -ConfigCombo $dry_var_global_ConfigCombo -Paths $dry_var_Paths
                $GLOBAL:dry_var_global_Configuration = Get-DryModuleConfig -ConfigCombo $dry_var_global_ConfigCombo -Configuration $GLOBAL:dry_var_global_Configuration 
                
                <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                
                    Credentials File
                    
                    The EnvConfig and/or ModuleConfig may provide placeholders for Credentials that DryDeploy 
                    will store in a local credentials file. Actions contain a cedentials node that specifies
                    'Aliases' to credentials that references credentials in the credentials file. If a 
                    referenced credential does not exist in the credentials file, the user will be prompted 
                    (unless -SuppressInteractivePrompts). Make sure to -Resolve before -Apply, so that all 
                    references are prompted for before you start a four hour long run. 
                    
                # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                New-DryCredentialsFile -Path $dry_var_global_CredentialsFile

                #! currently only support for 'encryptedstring', should support 'HashicorpVault', 1Password...
                if (-not $GLOBAL:dry_var_global_Configuration.CredentialsType) {
                    $GLOBAL:dry_var_global_Configuration | Add-Member -MemberType NoteProperty -Name 'CredentialsType' -Value 'encryptedstring'
                }
                
                if ($GLOBAL:dry_var_global_Configuration.Credentials) {
                    foreach ($dry_var_Credential in $GLOBAL:dry_var_global_Configuration.Credentials) {
                        $dry_var_AddCredentialPlaceholderParams = @{
                            Alias        = $dry_var_Credential.Alias
                            EnvConfig    = $GLOBAL:dry_var_global_ConfigCombo.envconfig.name
                            Type         = $GLOBAL:dry_var_global_Configuration.CredentialsType
                        }
                        if ($dry_var_Credential.UserName) {
                            $dry_var_AddCredentialPlaceholderParams += @{
                                UserName = $dry_var_Credential.UserName
                            }
                        }
                        Add-DryCredentialPlaceholder @dry_var_AddCredentialPlaceholderParams
                    }
                    $dry_var_AddCredentialPlaceholderParams = $null
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
                $dry_var_NewDryPlanParams = @{
                    ResourcesFile        = $dry_var_ResourcesFile
                    PlanFile             = $dry_var_PlanFile
                    Configuration        = $dry_var_global_Configuration
                    ConfigCombo          = $dry_var_global_ConfigCombo
                    ResourceNames        = $Resources
                    ExcludeResourceNames = $ExcludeResources
                    RoleNames            = $Roles
                    ExcludeRoleNames     = $ExcludeRoles
                    ActionNames          = $Actions
                    ExcludeActionNames   = $ExcludeActions
                    BuildSteps           = $BuildSteps
                    ExcludeBuildSteps    = $ExcludeBuildSteps
                    Phases               = $Phases
                    ExcludePhases        = $ExcludePhases
                    ArchiveFolder        = $dry_var_ArchiveDir
                }
                
                $dry_var_Plan = New-DryPlan @dry_var_NewDryPlanParams
                $dry_var_NewDryPlanParams = $null
                $dry_var_ShowDryPlanParams = @{
                    Plan                 = $dry_var_Plan
                    Mode                 = 'Plan' 
                    ConfigCombo          = $dry_var_global_ConfigCombo 
                    ShowConfigCombo      = $true
                    ShowDeselected       = $ShowDeselected
                }
                Show-DryPlan @dry_var_ShowDryPlanParams
                $dry_var_Plan = $null
                $dry_var_ShowDryPlanParams = $null
            }

            <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                
                Parameterset: Interactive

                Starts DryDeploy in interactive mode, which has the effect that resources specified in an 
                environment are ignored. Instead, a single resource will be defined from interactive 
                prompts, and a plan for that resource is created. You still need to have a module and an 
                environment selected. You may only select to build a resource from a role in the currently 
                selected system module.  
                
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
            'Interactive' {       
                $dry_var_NewDryPlanParams = @{
                    ResourcesFile        = $dry_var_ResourcesFile
                    PlanFile             = $dry_var_PlanFile
                    Configuration        = $dry_var_global_Configuration
                    ConfigCombo          = $dry_var_global_ConfigCombo
                    RoleNames            = $Roles
                    ExcludeRoleNames     = $ExcludeRoles
                    ActionNames          = $Actions
                    ExcludeActionNames   = $ExcludeActions
                    BuildSteps           = $BuildSteps
                    ExcludeBuildSteps    = $ExcludeBuildSteps
                    Phases               = $Phases
                    ExcludePhases        = $ExcludePhases
                    ArchiveFolder        = $dry_var_ArchiveDir
                }
                
                $dry_var_Plan = New-DryInteractivePlan @dry_var_NewDryPlanParams
                $dry_var_NewDryPlanParams = $null
                $dry_var_ShowDryPlanParams = @{
                    Plan                 = $dry_var_Plan
                    Mode                 = 'Plan' 
                    ConfigCombo          = $dry_var_global_ConfigCombo 
                    ShowConfigCombo      = $true
                    ShowDeselected       = $ShowDeselected
                }
                Show-DryPlan @dry_var_ShowDryPlanParams
                $dry_var_Plan = $null
                $dry_var_ShowDryPlanParams = $null
            }

            <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                
                Parameterset: Resolve
                
                Resolve gets the current plan, resolving all credentials, variables and options, but 
                does not modify the Plan or invoke any Action. You'll be prompted for any credential
                that cannot be found, 
                
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
            'Resolve' {
                $dry_var_GetDryPlanParams = @{
                    PlanFile             = $dry_var_PlanFile
                    ResourceNames        = $Resources
                    ExcludeResourceNames = $ExcludeResources
                    RoleNames            = $Roles
                    ExcludeRoleNames     = $ExcludeRoles
                    ActionNames          = $Actions
                    ExcludeActionNames   = $ExcludeActions
                    BuildSteps           = $BuildSteps
                    ExcludeBuildSteps    = $ExcludeBuildSteps
                    Phases               = $Phases
                    ExcludePhases        = $ExcludePhases
                }
                $dry_var_Plan            = Get-DryPlan @dry_var_GetDryPlanParams -ErrorAction Stop
                $dry_var_GetDryPlanParams = $null
                
                <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                
                    The iteration on every object in the Plan.  
                    
                # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                for ($dry_var_ActionCount = 1; $dry_var_ActionCount -le $dry_var_Plan.ActiveActions; $dry_var_ActionCount++ ) {
                    $dry_var_Action = $null
                    $dry_var_Action = $dry_var_Plan.Actions | Where-Object { $_.ApplyOrder -eq $dry_var_ActionCount }
                    
                    if ($Null -eq $dry_var_Action) { throw "Unable to find Action with Order $dry_var_ActionCount in Plan" }

                    try {
                        Show-DryActionStart -Action $dry_var_Action

                        # Used by Out-DryLog ('ol')
                        $GLOBAL:GlobalResourceName = $dry_var_Action.ResourceName
                        $GLOBAL:GlobalActionName   = $dry_var_Action.Action
                        if ($dry_var_Action.Phase -ge 1) {
                            $GLOBAL:GlobalPhase    = $dry_var_Action.Phase
                        }
                        else {
                            $GLOBAL:GlobalPhase    = $null
                        }

                        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                            
                            Read the Action's top Config.json, and resolve paths, variables etc

                        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                        $dry_var_ResolveActionOptionsParams = @{
                            Action        = $dry_var_Action 
                            Configuration = $dry_var_global_Configuration 
                            ConfigCombo   = $dry_var_global_ConfigCombo
                        }
                        $dry_var_Resolved = Resolve-DryActionOptions @dry_var_ResolveActionOptionsParams
                        $dry_var_Resolved
                        #! Should display the options object
                        
                    }
                    catch {
                        ol i "The terminating exception: " -sh
                        Show-DryUtilsError -Err $_
                        $dry_var_WarningString = "Failed action: [$($dry_var_Action.action)]"
                        if ($dry_var_Action.Phase) {
                            $dry_var_WarningString += " - Phase [$($dry_var_Action.Phase)]"
                        }
                        ol w $dry_var_WarningString
                        $PSCmdLet.ThrowTerminatingError($_)
                    }
                    finally {
                        $GLOBAL:GlobalResourceName = $null 
                        $GLOBAL:GlobalActionName = $null
                        $GLOBAL:GlobalPhase = $null
                    }
                }
            }

            <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                
                Parameterset: Apply
                
                Apply gets the current plan, and executes actions in the correct order. If retrying from 
                a previously failed attempt, it retries the failed Action and continues from there, if, 
                this time, it succeeds
                
            # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
            'Apply' {
                $dry_var_GetDryPlanParams = @{
                    PlanFile             = $dry_var_PlanFile
                    ResourceNames        = $Resources
                    ExcludeResourceNames = $ExcludeResources
                    RoleNames            = $Roles
                    ExcludeRoleNames     = $ExcludeRoles
                    ActionNames          = $Actions
                    ExcludeActionNames   = $ExcludeActions
                    BuildSteps           = $BuildSteps
                    ExcludeBuildSteps    = $ExcludeBuildSteps
                    Phases               = $Phases
                    ExcludePhases        = $ExcludePhases
                }
                $dry_var_Plan            = Get-DryPlan @dry_var_GetDryPlanParams -ErrorAction Stop
                $dry_var_GetDryPlanParams = $null

                <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                
                    The ConfigCombo will store hashes of all dependencies when you elevate Powershell and 
                    successfully run .\DryDeploy -Init. Once done, the tests below will pass on every 
                    subsequent run, until you change the configuration by -ModuleConfig and/or -EnvConfig. If 
                    you want to ignore that, since you know best, don't you? You may -IgnoreDependencies, 
                    upon which I will only display a warning. 
                    
                # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                #! implement  $dry_var_global_ConfigCombo.NeedsInit()
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
                for ($dry_var_ActionCount = 1; $dry_var_ActionCount -le $dry_var_Plan.ActiveActions; $dry_var_ActionCount++ ) {
                    $dry_var_Action = $null
                    $dry_var_Action = $dry_var_Plan.Actions | Where-Object { $_.ApplyOrder -eq $dry_var_ActionCount }
                    
                    if ($Null -eq $dry_var_Action) { throw "Unable to find Action with Order $dry_var_ActionCount in Plan" }

                    try {
                        if ($dry_var_Action.Status -eq 'Todo') {
                            $dry_var_Action.Status = 'Starting'
                            $dry_var_Plan.Save($dry_var_PlanFile,$false,$null)
                        }
                        elseif ($dry_var_Action.Status -eq 'Failed') {
                            $dry_var_Action.Status = 'Retrying'
                            $dry_var_Plan.Save($dry_var_PlanFile,$false,$null)
                        }
                        
                        Show-DryPlan -Plan $dry_var_Plan -Mode 'Apply' -ConfigCombo $dry_var_global_ConfigCombo
                        Show-DryActionStart -Action $dry_var_Action

                        # Used by Out-DryLog ('ol')
                        $GLOBAL:GlobalResourceName = $dry_var_Action.ResourceName
                        $GLOBAL:GlobalActionName   = $dry_var_Action.Action
                        if ($dry_var_Action.Phase -ge 1) {
                            $GLOBAL:GlobalPhase    = $dry_var_Action.Phase
                        }
                        else {
                            $GLOBAL:GlobalPhase    = $null
                        }
                        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                            
                            Make an ass out of you and me (assume) the worst. In the Plan written to file, make
                            sure the Action has a status of 'Failed' before it starts. The only way the Action
                            in the Plan on file may switch to a status of 'Success' is if all goes well

                        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                        $dry_var_Action.Status = 'Failed'
                        $dry_var_Plan.Save($dry_var_PlanFile,$false,$null)

                        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                            
                            Read the Action's top Config.json, and resolve paths, variables etc

                        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                        $dry_var_ResolveActionOptionsParams = @{
                            Action        = $dry_var_Action 
                            Configuration = $dry_var_global_Configuration 
                            ConfigCombo   = $dry_var_global_ConfigCombo
                        }
                        $dry_var_Resolved = Resolve-DryActionOptions @dry_var_ResolveActionOptionsParams

                        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                            
                            Import the action function

                        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                        
                        $dry_var_ActionName = "dry.action.$($dry_var_Action.Action)"
                        ol i @('Action Module/Name',"$dry_var_ActionName")
                        $dry_var_ActionName | Import-Module -Force -ErrorAction Stop

                        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                            
                            Params to send to the action function

                        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                        $dry_var_ActionParams = @{
                            Action        = $dry_var_Action 
                            Configuration = $dry_var_global_Configuration
                            Resolved      = $dry_var_Resolved
                        }
                        
                        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                        
                            You may call "DryDeploy -Apply -ActionParams @{'param1'='value1'}" to pass a hashtable
                            of names and values to the action-function if it supports some way of filtering on certain 
                            parts of the configuration, however this params are highly Action specific, so the action
                            function will automatically quit after this.

                        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                        if ($ActionParams) {
                            $dry_var_ActionParams+=@{'ActionParams'=$ActionParams}
                            $Quit = $true
                        }

                        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                            Execute Action
                        
                            This is where the Action function get's called

                        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                        
                        $dry_var_ActionStartTime = Get-Date
                        & $dry_var_ActionName @dry_var_ActionParams
                        $dry_var_ActionEndTime = Get-Date
                        # No Catch?  
                        $dry_var_Action.Status = 'Success'

                        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                            Update the IP of the resource in the plan if the Action is an IP-resolving Action. P.t. 
                            only a terra.run-action has this functionality, but custom script actions may be created,
                            it only requires that the action puts an ip into either of the globally defined variables 
                            $GLOBAL:dry_var_global_ResolvedIPv4 or $GLOBAL:dry_var_global_ResolvedIPv6

                        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                        if ($dry_var_Action.resource.resolved_network.ip_address -eq 'dhcp') {
                            $dry_var_AnIpWasResolved = $false
                            if ($null -ne $GLOBAL:dry_var_global_ResolvedIPv4) {
                                ol i @("Detected a resolved IP", "$($GLOBAL:dry_var_global_ResolvedIPv4)")
                                foreach ($dry_var_SetIPAction in ($dry_var_Plan.Actions | Where-Object { $_.resource.resource_guid -eq $dry_var_Action.resource.resource_guid})) {
                                    $dry_var_SetIPAction.resource.resolved_network.ip_address = "$($GLOBAL:dry_var_global_ResolvedIPv4)"
                                }
                                
                                $dry_var_Plan.Save($dry_var_PlanFile,$false,$null)
                                $GLOBAL:dry_var_global_ResolvedIPv4 = $null
                                $dry_var_AnIpWasResolved = $true
                            }
                            if ($null -ne $GLOBAL:dry_var_global_ResolvedIPv6) {
                                foreach ($dry_var_SetIPAction in ($dry_var_Plan.Actions | Where-Object { $_.resource.resource_guid -eq $dry_var_Action.resource.resource_guid})) {
                                    $dry_var_SetIPAction.resource.resolved_network.ip_address6 = "$($GLOBAL:dry_var_global_ResolvedIPv6)"
                                }
                                $dry_var_Plan.Save($dry_var_PlanFile,$false,$null)
                                $GLOBAL:dry_var_global_ResolvedIPv6 = $null
                                $dry_var_AnIpWasResolved = $true
                            }
                            if ($dry_var_AnIpWasResolved) {
                                if ($dry_var_Action.resource.resolved_network.ip_address -ne 'dhcp') {
                                    ol i "The resource uses DHCP, and it's IP was resolved to $($dry_var_Action.resource.resolved_network.ip_address)"
                                }
                                elseif ($dry_var_Action.resource.resolved_network.ip_address6 -ne 'dhcp') {
                                    ol i "The resource uses DHCP, and it's IPv6 was resolved to $($dry_var_Action.resource.resolved_network.ip_address6)"
                                }
                                else {
                                    ol w "The resource's IP should have been resolved, but wasn't?"
                                    throw "The resource's IP should have been resolved, but wasn't?"
                                }
                            }
                            else {
                                ol w "The resource uses DHCP, but IP not resolved yet. It may be scheduled to be resolved later in plan"
                            }
                        }

                        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                            Quit

                            You may call 
                                DryDeploy -Apply -Quit
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
                                DryDeploy -Apply -Step
                            to make DryDeploy wait for you to press ENTER before continuing to the next 
                            Action, or Q to quit, if you're unhappy about something. 
                            
                        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                        if ($Step) {
                            $dry_var_StepResponse = Read-Host -Prompt "Press ENTER to continue or Q(uit) to quit"
                            if (($dry_var_StepResponse -eq 'q') -or ($dry_var_StepResponse -eq 'quit')) { 
                                break
                            }
                        }
                    }
                    catch {
                        $dry_var_Action.Status = 'Failed'
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
                                }
                                else {
                                    ol i "Previous exception $ec`:" -sh
                                }
                                if ($Error[$ec].GetType().Name -eq 'ErrorRecord') {
                                    Show-DryUtilsError -Err $Error[$ec]
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
                            Show-DryUtilsError -Err $_
                        }

                        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                            If we reach a catch, create a warning on the DD Action, but throw the original exception

                        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
                        $dry_var_WarningString = "Failed action: [$($dry_var_Action.action)]"
                        if ($dry_var_Action.Phase) {
                            $dry_var_WarningString += " - Phase [$($dry_var_Action.Phase)]"
                        }
                        ol w $dry_var_WarningString
                        $PSCmdLet.ThrowTerminatingError($_)
                    }
                    finally {
                        $dry_var_Plan.Save($dry_var_PlanFile,$false,$null)
                        $dry_var_ActionEndTime = Get-Date
                        $GLOBAL:GlobalResourceName = $null 
                        $GLOBAL:GlobalActionName = $null
                        $GLOBAL:GlobalPhase = $null
                        Remove-Module -Name "dry.action.$($dry_var_Action.Action)" -ErrorAction Ignore
                        Show-DryActionEnd -Action $dry_var_Action -StartTime $dry_var_ActionStartTime -EndTime $dry_var_ActionEndTime
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

            Show the final plan and it's status if apply mode

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        if ($PSCmdlet.ParameterSetName -eq 'Apply') {
            $ShowDryPlanParams       = @{
                Plan                 = $dry_var_Plan
                Mode                 = 'Apply' 
                ConfigCombo          = $dry_var_global_ConfigCombo 
                ShowConfigCombo      = $true
                ShowDeselected       = $false
            }
            Show-DryPlan @ShowDryPlanParams
            $ShowDryPlanParams = $null
        }
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            Reset DD's global Action-specific variables

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        $GLOBAL:GlobalResourceName = $null 
        $GLOBAL:GlobalActionName   = $null
        $GLOBAL:GlobalPhase        = $null
        
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            Reset Powershell's Global Preference variables

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        $GLOBAL:VerbosePreference     = $dry_var_GlobalVerbosePreference
        $GLOBAL:DebugPreference       = $dry_var_GlobalDebugPreference
        $GLOBAL:ErrorActionPreference = $dry_var_GlobalErrorActionPreference
        ol i "DryDeploy $($PSCmdLet.ParameterSetName): outro" -sh -air
        ol i ' '

        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            Reset $PSModulePath

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        $env:PSModulePath = $dry_var_OriginalPSModulePath
        
        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            Remove all DryDeploy modules

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        Get-Module | Where-Object { 
            ($_.Name -match "^dry\.action\.*") -or 
            ($_.Name -match "^dry\.module\.*")} | 
        Remove-Module -Force

        <# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

            Remove all DryDeploy variables

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #>
        Get-Variable -Scope Local | Where-Object {$_.Name -match '^dry_var_*'} | Remove-Variable -Scope Local -Force
        Get-Variable -Scope Global | Where-Object {$_.Name -match '^dry_var_*'} | Remove-Variable -Scope Global -Force
    }
}