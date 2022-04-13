<#
.SYNOPSIS
DryDeploy.ps1 prepares your deployment platform (-Init, -Moduleinit), 
stores paths to a configuration combination of a EnvConfig and a 
ModuleConfig, creates a plan of Actions to perform based on the 
configurations and any filters specified (-Plan), and applies the 
plan in the configured order (-Apply). Run DryDeploy.ps1 without any 
parameters to show the deployment status of the current Plan.

.DESCRIPTION
DryDeploy.ps1 needs 2 configuration repositories: 

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
Initiates, meaning that it installs dependencies, like Chocolatey, 
Packer, some external modules from PSGallery, and the core DryDeploy
modules. Must be executed as an administrator (elevated). The core 
modules are installed for the system.

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

.PARAMETER BuildOrders
Array of one or more BuildOrders to include. All others are 
excluded. If not specified, all BuildOrders are included. 

.PARAMETER ExcludeBuildOrders
Array of one or more BuildOrders to exclude. All others are 
included. If not specified, all BuildOrders are included. 

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

.PARAMETER EnvConfigPath
Path to the Directory where the EnvConfiguration is. Use to 
set the configuration combination (ConfigCombo)

.PARAMETER ModuleConfigPath
Path to the Directory where the ModuleConfiguration is. Use to 
set the configuration combination (ConfigCombo)

.PARAMETER ActionParams
HashTable that will be sent to the Action Function. Useful during 
development, for instance if the receiving action function 
supports a parameter to specify a limited set of tasks to do. 

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
.\DryDeploy.ps1 -ModuleConfigPath ..\ModuleConfigs\MyModule -EnvConfigPath ..\EnvConfigs\MyEnvironment
Creates a configuration combination of a Module Configuration and
a Env Configuration. The combination (the "ConfigCombo") is stored
and used on subsequent runs until you change any of them again

.EXAMPLE
.\DryDeploy.ps1 -ModuleInit
Will prepare your system for deployment of a specific ModuleConfig. 
Installs a module's dependencies, including chocos, gits, powershell 
modules and so on

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
#>
[CmdLetBinding(DefaultParameterSetName='ShowPlan')]
param (
    
    [Parameter(ParameterSetName='Init',
    HelpMessage='Downloads dependencies for DryDeploy. Must run 
    once on the system you are working from, and must run elevated 
    (Run as Administrator)')]
    [Switch]
    $Init,

    [Parameter(ParameterSetName='Init',
    HelpMessage='Downloads dependencies for the system module you
    are deploying. If any chocos needs to be installed, you have to
    run elevated (Run as Administrator)')]
    [Switch]
    $ModuleInit,
    
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
    $BuildOrders,

    [Parameter(ParameterSetName='Plan',
    HelpMessage='Array of one or more ActionsOrders to exclude. All 
    others are included. If not specified, all ActionsOrders are 
    included.')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Array of one or more ActionsOrders to exclude. All 
    others are included. If not specified, all ActionsOrders are 
    included.')]
    [Int[]]
    $ExcludeBuildOrders,

    [Parameter(ParameterSetName='Plan',
    HelpMessage='Array of one or more Resource names to include. 
    All others are excluded. If not specified, all Resources are 
    included')]
    [Parameter(ParameterSetName='Apply',
    HelpMessage='Array of one or more Resource names to include. 
    All others are excluded. If not specified, all Resources are 
    included')]
    [ArgumentCompleter({((Get-Content -Path (Join-Path ((Get-Content `
        (Join-Path (Join-Path $($env:localappdata) DryDeploy) `
        ConfigCombo.json) | ConvertFrom-Json).InstanceConfig.Path) `
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
    $EnvConfigPath,

    [Parameter(ParameterSetName='SetConfig',
    HelpMessage="Path to the directory where the ModuleConfig is. 
    Once set, the ConfigCombo (the combination of a EnvConfig, 
    a ModuleConfig and an InstanceConfig) will be stored and reused  
    for each subsequent action")]
    [String]
    $ModuleConfigPath,

    [Parameter(ParameterSetName='Apply',
    HelpMessage="Specify a hashtable of parameters to splat to 
    Actions. All receiving action function must accept all parameters. 
    So use only when running individual actions")]
    [Hashtable]
    $ActionParams,


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
    DryDeploy itself")]
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

if ($ShowAllErrors) {
    $Error.clear()
}

try {
    $GLOBAL:ShowStatus = $ShowStatus
    $GLOBAL:SuppressInteractivePrompts = $SuppressInteractivePrompts
    $GLOBAL:Force = $Force
    $GLOBAL:ShowPasswords = $ShowPasswords
    $GLOBAL:KeepConfigFiles = $KeepConfigFiles
    $GLOBAL:WarnOnTooNarrowConsole = $true

    # The environment we're running in
    $DryEnvironment = [PSObject]@{
        Edition  = $PSversionTable.PSEdition
        Version  = $PSversionTable.PSVersion.ToString()
        Platform = & { switch ($PSVersionTable.Platform) { $null {return 'Win32NT'} default {return $PSVersionTable.Platform }}}
        Home     = ''
    }
    $DryEnvironment.Home = & { switch ($DryEnvironment.Platform) { 
        'Win32NT' {return "$($env:UserProfile)" } 
        'Unix' {return "$($env:HOME)" }
    }}
    $GLOBAL:DryEnvironment = $DryEnvironment

    # 
    switch ($GLOBAL:DryEnvironment.Platform) {
        'Win32NT' {
            $slash = '\'
            $separator = ';'
        }
        'Unix' {
            $slash = '/'
            $separator = ':'
        }
    }

    # This scripts add paths to PSModulePath - make sure we can restore to the original in Finally
    $OriginalPSModulePath = $env:PSModulePath

    # Get the current global preference values, so they can be set back in finally
    $GlobalVerbosePreference      = $GLOBAL:VerbosePreference 
    $GlobalDebugPreference        = $GLOBAL:DebugPreference
    $GlobalErrorActionPreference  = $GLOBAL:ErrorActionPreference

    # Set global preferences, so -Verbose and -Debug works down the stack 
    $GLOBAL:VerbosePreference     = $PSCmdlet.GetVariableValue('VerbosePreference')
    $GLOBAL:DebugPreference       = $PSCmdlet.GetVariableValue('DebugPreference')
    $GLOBAL:ErrorActionPreference = 'Stop'

    # using -debug sets $DebugPreference = 'Inquire' - we want it to 'Continue'. 
    if ($GLOBAL:DebugPreference -eq 'Inquire') { 
        $GLOBAL:DebugPreference   = 'Continue' 
        $SCRIPT:DebugPreference   = 'Continue'
    }

    # find full path the script is running from 
    if (($null -ne $PSScriptRoot) -And (Test-Path -Path $PSScriptRoot -ErrorAction 'Ignore')) {
        $ScriptPath = $PSScriptRoot
    }
    elseif (((Split-Path -Path $MyInvocation.MyCommand.Path) -match "^[a-zA-Z]\:\\") -or
            ((Split-Path -Path $MyInvocation.MyCommand.Path) -match "^/")) {
        $ScriptPath = Split-Path -Path $MyInvocation.MyCommand.Path
    }
    else {
        throw 'Unable to determine script path'
    }
    $GLOBAL:ScriptPath           = $ScriptPath
    
    $DryDeployProjectMapPath     = Join-Path -Path $ScriptPath -ChildPath 'Project.json'

    # add DryDeploy's modules and actions into $ENV:PSModulePath
    #$LocalModulesDirectory = [IO.Path]::GetFullPath("$ScriptPath\modules")
    $LocalModulesDirectory = [IO.Path]::GetFullPath("$(Join-Path -Path $ScriptPath -ChildPath 'modules')")
    $LocalActionsDirectory = [IO.Path]::GetFullPath("$(Join-Path -Path $ScriptPath -ChildPath 'actions')")
    switch ($GLOBAL:DryEnvironment.Platform) {
        'Win32NT' {
            if ($env:PSModulePath -notmatch ($LocalModulesDirectory -replace'\\','\\')) {
                $env:PSModulePath = "$($env:PSModulePath);$LocalModulesDirectory" 
            }
            if ($env:PSModulePath -notmatch ($LocalActionsDirectory -replace'\\','\\')) {
                $env:PSModulePath = "$($env:PSModulePath);$LocalActionsDirectory" 
            }
            $RootWorkingDirectory = Join-Path -Path "$($env:UserProfile)" -ChildPath 'DryDeploy'
        }
        'Unix' {
            if ($env:PSModulePath -notmatch $LocalModulesDirectory) {
                $env:PSModulePath = "$($env:PSModulePath):$LocalModulesDirectory" 
            }
            if ($env:PSModulePath -notmatch $LocalActionsDirectory) {
                $env:PSModulePath = "$($env:PSModulePath):$LocalActionsDirectory" 
            }
            $RootWorkingDirectory = Join-Path -Path "$($env:HOME)" -ChildPath 'DryDeploy'
        }
        default {
            throw "Platform unknown: ($($GLOBAL:DryEnvironment.Platform)). DryDeploy runs on Windows and Linux only"
        }
    }
    
    # Define RootWorkingDirectory where temporary files are written
    Set-Variable -Name RootWorkingDirectory -Value $RootWorkingDirectory -Scope Global -Force

    $ProjectMap = Get-Content -Path $DryDeployProjectMapPath -ErrorAction Stop | 
    ConvertFrom-Json -ErrorAction Stop

    # Set options for logging
    Set-DryLoggingOptions -Config $ProjectMap -RootWorkingDirectory $RootWorkingDirectory -nolog:$nolog
    
    [String]$PlanFile        = Join-Path -Path $RootWorkingDirectory -ChildPath 'DryPlan.json'
    [String]$ResourcesFile   = Join-Path -Path $RootWorkingDirectory -ChildPath 'DryResources.json'
    [String]$CredentialsFile = Join-Path -Path $RootWorkingDirectory -ChildPath 'Credentials.json'
    [String]$CurrentsFile    = Join-Path -Path $RootWorkingDirectory -ChildPath 'Current.json'
    [String]$ConfigCombosDir = Join-Path -Path $RootWorkingDirectory -ChildPath 'ConfigCombos'
    [String]$LogsArchiveDir  = Join-Path -Path $RootWorkingDirectory -ChildPath 'ArchivedLogs'
    
    @($RootWorkingDirectory,$ConfigCombosDir,$LogsArchiveDir).foreach({
        if (-not (Test-Path "$_" -ErrorAction Ignore)) {
            New-Item -ItemType Directory -Path "$_" -Force | Out-Null
        }
    })
    
    if (Test-Path -Path $CurrentsFile -ErrorAction Ignore) {
        $CurrentsObject = Get-Content -Path $CurrentsFile -Encoding default -ErrorAction Stop | 
        ConvertFrom-Json -ErrorAction Stop
    }
    else {
        $CurrentsObject = New-Object -TypeName PSObject -Property @{
            config_combo = 'default'
            dependencies_hash = ''
        }
        $CurrentsObject | 
        ConvertTo-Json -Depth 4 -ErrorAction Stop | 
        Out-File -FilePath $CurrentsFile -Encoding default -ErrorAction Stop
    }

    [String]$ConfigComboPath = Join-Path -Path $ConfigCombosDir -ChildPath "$($CurrentsObject.config_combo).json"

    # Get the names of all loaded modules. If any of 'our' modules are loaded
    # they should be removed, so new commits are picked up when they are used
    $ImportedModules = @((Get-Module | Select-Object -Property Name).Name)
    foreach ($Module in $ImportedModules) {
        if (($Module -match "^dry\.module\.*") -or ($Module -match "^dry\.action\.*")) {
            Remove-Module -Name $Module -ErrorAction SilentlyContinue -Verbose:$False -Force
        }
    }
    if ($ProjectMap.nuget.modules) {
        foreach ($Module in $ProjectMap.nuget.modules) {
            if ($ImportedModules -contains $Module.Name) {
                Remove-Module -Name $Module.Name -ErrorAction SilentlyContinue -Verbose:$False -Force
            }     
        }
    }

    # Greet the minions
    $DryDeployHeaderChar = '.' # <-- experimenting with different headerchars when too lazy to code
    $Helloes = @('Hello','Hola','Ciao','Bonjour','Ola','Hallo','Ahoj','Zdravstvuyte')
    ol i "DryDeploy $($Helloes | Get-Random)" -sh -hchar $DryDeployHeaderChar -air
    ol i ' '

    # Make path to logfile global, archive existing log and create new log file
    if (($ProjectMap.logging.path) -and ($ProjectMap.logging.log_to_file -eq $True)) {
        if (Test-Path -Path $ProjectMap.logging.path -ErrorAction SilentlyContinue) {
            #! Should be a path, not a subfolder
            Save-DryArchiveFile -ArchiveFile $ProjectMap.logging.path -ArchiveSubFolder 'ArchivedLogs'     
        }
        New-Item -Path $ProjectMap.logging.path -Force | Out-Null
        ol v @('You may use cmtrace.exe to view log file at',"$($ProjectMap.logging.path)")
    }
    if ($PSCmdLet.ParameterSetName -eq 'Apply') {
        if ($Force -or $ShowPasswords -or $KeepConfigFiles -or $DestroyOnFailedBuild) {
            ol w 'Warnings' -h
            if ($Force) {
                ol w @('Using switch -Force','IF YOU''RE TRYING TO BUILD A RESOURCE THAT EXIST, THIS WILL DESTROY THE EXISTING RESOURCE')
            }
            if ($ShowPasswords) {
                ol w @('Using switch -ShowPasswords','THIS WILL SHOW CLEAR-TEXT-PASSWORDS IN LOGFILE AND IN CONSOLE OUTPUT')
            }
            if ($KeepConfigFiles) {
                ol w @('Using switch -KeepConfigFiles','This will keep temporary configfiles in <PROFILE>\DryDeploy (until overwritten)')
            }
            if ($DestroyOnFailedBuild) {
                ol w @('Using switch -DestroyOnFailedBuild','This will destroy artifacts that fail during build')
            }
            ol w '' -h
        }
    }
    
    # If the switch -cmtrace was passed, and cmtrace.exe is in path and the LogFile exists, launch cmtrace.exe with the LogFile
    if ($CmTrace) {
        if ((Get-Command -name 'cmtrace.exe' -ErrorAction Ignore) -and 
        (Test-Path -Path $ProjectMap.logging.path)) {
            & "cmtrace.exe" $ProjectMap.logging.path
        } 
        else {
            Write-Warning "Unable to find cmtrace or the logfile '$($ProjectMap.logging.path)' - cmtrace will not start."
        }
    }

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # 
    #   Config Combo 
    #
    #   The ConfigCombo is a combination of a EnvConfig and a ModuleConfig. The 
    #   object stores paths to those configurations, and will reuse the already 
    #   stored values each time you -Plan and -Apply. You may modify the ConfigCombo 
    #   by specifying -EnvConfig or -ModuleConfig
    #
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    $GLOBAL:ConfigCombo = Get-DryConfigCombo -Path $ConfigComboPath

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # 
    #   INIT and MODULEINIT
    #    - Register modules providers
    #    - Installs dependency modules
    #    - Clones dependent git repos   
    #
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    if ($Init) {
        ol i "Resolving DryDeploy's dependencies" -sh
        if (Test-DryElevated){
            Install-DryDependencies -Dependencies $ProjectMap.Dependencies -ConfigObjectPath $CurrentsFile
        }
        else {
            ol i " "
            ol w "Run -init elevated to resolve dependencies (right-click PowerShell and 'Run as Administrator')"
            ol i " "
            ol i " "
            throw "Init requires PowerShell to run elevated ('Run as Administrator')"
        }
        return
    }
    if ($ModuleInit) {
        ol i "Resolving dependencies for the system module" -sh
        if (
            ($null -ne $ConfigCombo.ModuleConfig.path) -and 
            ('' -ne $ConfigCombo.ModuleConfig.path)
        ) {
            $ConfigObjectPath = Join-Path -Path $ConfigCombo.ModuleConfig.path -ChildPath 'Config.json'
            $ConfigObject = Get-Content -Path $ConfigObjectPath -Encoding default -ErrorAction Stop | 
            ConvertFrom-Json -ErrorAction Stop
            
            if ($ConfigObject.dependencies) {
                Install-DryDependencies -Dependencies $ConfigObject.dependencies -ConfigObjectPath $ConfigComboPath
            }
            return
        }
    }

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # 
    #   SetConfig 
    #   Creates or modifies the Configuration Combination (ConfigCombo)
    #
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    #! go through - does not make much sense
    if ($EnvConfigPath -or $ModuleConfigPath) {
        # Resolve the EnvConfig
        if ($EnvConfigPath) {
            #Resolve-DryConfigCombo -Path ([IO.Path]::GetFullPath("$EnvConfigPath")) -Type 'Global'
            Resolve-DryConfigCombo -Path (Resolve-DryFullPath -Path $EnvConfigPath -RootPath $ScriptPath) -Type 'Global'
        }
        else {
            Resolve-DryConfigCombo -Type 'Global' -ErrorAction 'Continue'
        }
        Save-DryConfigCombo -Path $ConfigComboPath -ConfigCombo $ConfigCombo

        # Resolve the ModuleConfig
        if ($ModuleConfigPath) {
            Resolve-DryConfigCombo -Path (Resolve-DryFullPath -Path $ModuleConfigPath -RootPath $ScriptPath) -Type 'Module'
        }
        else {
            Resolve-DryConfigCombo -Type 'Module' -ErrorAction 'Continue'
        }
        Save-DryConfigCombo -Path $ConfigComboPath -ConfigCombo $ConfigCombo
    }

    if ($Plan -or $Apply) {

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #   ENVIRONMENT CONFIGURATION
        #
        #   The Env Configuration contains environment specific, common, shared 
        #   configurations that every developer should use as a base config when 
        #   developing or deploying a ModuleConfig. Every environment should  
        #   have it's own, customized environment config, which is shared among the 
        #   Ops team.  
        #
        #   The EnvConfig is a directory or repository containing two directories; 
        #   
        #   1. 'Config' which contain common environment specific definitions 
        #      
        #   2. 'OSConfig' which contain os-specific definitions
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    
        $EnvConfigDirectory = $ConfigCombo.EnvConfig.Path

        # Mandatory Env Configuration directories
        $EnvConfigDirectoryConfig    = Join-Path -Path $EnvConfigDirectory -ChildPath 'Config'
        $EnvConfigDirectoryOSConfig  = Join-Path -Path $EnvConfigDirectory -ChildPath 'OSConfig'
        
        @($EnvConfigDirectoryConfig,$EnvConfigDirectoryOSConfig).Foreach({
            try {
                Test-Path -Path $_ -ErrorAction Stop | Out-Null
            }
            catch {
                ol e "Missing Mandatory Directory '$_'"
                throw "Missing Mandatory Directory '$_'"
            }
        })
        
        # Pick up all jsons (*.json) and commented jsons (*.jsonc), and merge into the $Configuration
        Remove-Variable -Name Configuration -ErrorAction Ignore
        $Configuration = New-Object PSObject
        
        $EnvConfigurationRepoFiles = @(Get-ChildItem -Path (Join-Path -Path $EnvConfigDirectoryConfig -ChildPath '*') -Include "*.jsonc","*.json" -ErrorAction Stop)
        foreach ($ConfFile in $EnvConfigurationRepoFiles) {

            # $ConfObject = Get-Content -Path $ConfFile.fullname -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            $ConfObject = Get-DryCommentedJson -Path $ConfFile.FullName -ErrorAction Stop
            # Merge with $Configuration
            $Configuration = (Merge-DryPSObjects -FirstObject $Configuration -SecondObject $ConfObject)
        }

        # Add the resolved OS Configuration directory to the Configuration so that functions
        # below may use that instead of having to resolve relative paths over and over
        $Configuration | Add-Member -MemberType NoteProperty -name OSConfigDirectory -value $EnvConfigDirectoryOSConfig

        # the metaconfiguration should contain a name property used to tag credential aliases for specific environments
        [String]$EnvConfigName  = (Get-Content -Path (Join-Path -Path $EnvConfigDirectory -ChildPath 'Config.json') -ErrorAction Stop | 
        ConvertFrom-Json -ErrorAction Stop).Name
        if (($EnvConfigName.Trim() -eq '') -or ($null -eq $EnvConfigName)) {
            throw "The EnvConfig is missing a 'name' property in root file 'Config.json'"
        }
        $GLOBAL:EnvConfigName = $EnvConfigName

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #   MODULE CONFIGURATION 
        #   The ModuleConfig contains
        #
        #   1. a Roles folder, that contains one or more folders named 
        #      after the Roles that make up the module. Each 
        #      Role folder contains a folder for each Action that requires 
        #      configuration file(s) 
        #
        #   2. a Build folder, that contains a json/jsonc defining the 
        #      'build', that specifies the order in which configuration
        #      options of the module are deployed, and the order of the actions that
        #      creates and configures a resource of a specific Role
        #
        #   The ModuleConfig should be generic in the sense that it should be able to 
        #   be used as is, without modification, in any environment. When there are 
        #   environmental differences, those differences should be implemented using
        #   queries against configurations specified in the EnvConfiguration. The
        #   EnvConfiguration must contain some key nodes, but has no finit scheme - 
        #   it may be infinately expanded to support any oject or list needed by a 
        #   module. 
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #  
        $ModuleConfigDirectory = $ConfigCombo.ModuleConfig.Path

        # Mandatory Module Configuration directories
        $RoleConfigs            = Join-Path -Path $ModuleConfigDirectory -ChildPath 'Roles'
        $BuildPath        = Join-Path -Path $ModuleConfigDirectory -ChildPath 'Build'
        $ModuleCredentialsPath  = Join-Path -Path $ModuleConfigDirectory -ChildPath 'Credentials'
        
        @($RoleConfigs,$BuildPath).Foreach({
            try {
                Test-Path -Path $_ -ErrorAction Stop | Out-Null
            }
            catch {
                ol e "Missing mandatory file or directory '$_'"
                throw "Missing mandatory file or directory '$_'"
            }
        })
        
        $GLOBAL:RoleConfigs = $RoleConfigs
        
        # Pick up all jsons (*.json) and commented jsons (*.jsonc), and merge into the $Configuration
        $ModuleConfigurationRepoFiles = @(Get-ChildItem -Path (Join-Path -Path $BuildPath -ChildPath '*') -Include "*.jsonc","*.json" -ErrorAction Stop)
        
        foreach ($ConfFile in $ModuleConfigurationRepoFiles) {
            # $ConfObject = Get-Content -Path $ConfFile.fullname -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            $ConfObject = Get-DryCommentedJson -Path $ConfFile.fullname -ErrorAction Stop
            # Merge with $ModuleConfiguration
            $Configuration = (Merge-DryPSObjects -FirstObject $Configuration -SecondObject $ConfObject)
        }

        # Add the resolved configuration directory to the Configuration so that functions
        # below may use that instead of having to resolve relative paths over and over
        $Configuration | Add-Member -MemberType NoteProperty -name ModuleConfigDirectory -value $ModuleConfigDirectory

        # Each folder below $RoleConfigs should have a Config.Json containing
        # meta properties for the Roles. Pick up and create a an array 
        # RoleMetaConfigs, and add to the configuration. 
        $RoleConfigsFolders = Get-ChildItem -Path $RoleConfigs -Attributes Directory -ErrorAction Stop
        $COObjects = @()
        $RoleConfigsFolders.foreach({
            $COObject = New-Object -TypeName PSObject 
            $COObjectJson = Get-Content -Path (Join-Path -Path $_.FullName -ChildPath 'Config.json') -ErrorAction Stop | 
            ConvertFrom-Json -ErrorAction Stop

            $COObjectJson.PSObject.Properties.Foreach({
                $COObject | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value
            })
            $COObjects+=$COObject
        })
        $Configuration | Add-Member -MemberType NoteProperty -Name RoleMetaConfigs -Value $COObjects

        # Credentials 
        if (Test-Path -Path $ModuleCredentialsPath) {
            $ModuleCredentialsFiles = @(Get-ChildItem -Path (Join-Path -Path $ModuleCredentialsPath -ChildPath '*') -Include "*.jsonc","*.json" -ErrorAction Stop)
            foreach ($CredFile in $ModuleCredentialsFiles) {
                $ConfObject = Get-DryCommentedJson -Path $CredFile.fullname -ErrorAction Stop
                $Configuration = (Merge-DryPSObjects -FirstObject $Configuration -SecondObject $ConfObject)
            }
        }

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #   COMMON VARIABLES 
        #
        #   Pick up and create any common variable
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        if ($Configuration.common_variables) {
            $CommonVariables = Resolve-DryVariables -Variables $Configuration.common_variables -Configuration $Configuration -OutputType 'list'
            $CommonVariables.foreach({
                if (Get-Variable -Name $_.Name -Scope GLOBAL -ErrorAction Ignore) {
                    Set-Variable -Name $_.Name -Value $_.Value -Scope GLOBAL
                }
                else {
                    New-Variable -Name $_.Name -Value $_.Value -Scope GLOBAL
                }
            }) 
        }

        # Replace any common ReplacementPattern ("###($Variable.name)###") in $Configuration
        $Configuration = Resolve-DryReplacementPatterns -InputObject $Configuration -Variables $CommonVariables

        # make global
        Set-Variable -Name Configuration -Value $Configuration -Scope GLOBAL -Option AllScope

        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
        # 
        #   Credentials File
        #
        #   The Env Configuration should supply a template for the credentials 
        #   config. 
        #
        # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

        # Make sure the credentialsfile exists
        $GLOBAL:CredentialsFile = $CredentialsFile
        New-DryCredentialsFile

        #! currently only support for 'encryptedstring'
        if ($Configuration.CredentialsType) {
            $GLOBAL:CredentialsType = $Configuration.CredentialsType
        }
        else {
            $GLOBAL:CredentialsType = 'encryptedstring'
        }
        
        if ($Configuration.Credentials) {
            foreach ($Credential in $Configuration.Credentials) {
                $AddCredentialPlaceholderParams = @{
                    Alias        = $Credential.Alias
                    EnvConfig = $EnvConfigName
                    Type         = $CredentialsType
                }
                if ($Credential.UserName) {
                    $AddCredentialPlaceholderParams += @{
                        UserName = $Credential.UserName
                    }
                }
                Add-DryCredentialPlaceholder @AddCredentialPlaceholderParams
            }
        }
    }

    if ((-not ($PSCmdLet.ParameterSetName -eq 'Plan')) -and 
        (-not ($PSCmdLet.ParameterSetName -eq 'Apply')) -and 
        (-not ($PSCmdLet.ParameterSetName -eq 'Init')) -and  
        (-not ($PSCmdLet.ParameterSetName -eq 'SetConfig'))
    ) {
        $GetDryPlanParams = @{
            PlanFile             = $PlanFile
            ResourceNames        = $Resources
            ExcludeResourceNames = $ExcludeResources
            ActionNames          = $Actions
            ExcludeActionNames   = $ExcludeActions
            BuildOrders          = $BuildOrders
            ExcludeBuildOrders   = $ExcludeBuildOrders
            Phases               = $Phases
            ExcludePhases        = $ExcludePhases
            ShowStatus           = $True
        }
        $PlanObj                 = Get-DryPlan @GetDryPlanParams -ErrorAction Stop

        $ShowDryPlanParams       = @{
            Plan                 = $PlanObj
            Mode                 = 'Plan' 
            ConfigCombo          = $ConfigCombo 
            ShowConfigCombo      = $True
            ShowDeselected       = $ShowDeselected
        }
        Show-DryPlan @ShowDryPlanParams
    }

    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # 
    #   PLAN 
    #   -Plan archives any existing plan, and creates a new plan for all resources 
    #   based on the build, and displays the plan
    #
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    
    if ($Plan) { 
        $NewDryPlanParams        = @{
            ResourcesFile        = $ResourcesFile
            PlanFile             = $PlanFile
            Configuration        = $Configuration
            CommonVariables      = $CommonVariables
            ResourceNames        = $Resources
            ExcludeResourceNames = $ExcludeResources
            ActionNames          = $Actions
            ExcludeActionNames   = $ExcludeActions
            BuildOrders         = $BuildOrders
            ExcludeBuildOrders  = $ExcludeBuildOrders
            Phases               = $Phases
            ExcludePhases        = $ExcludePhases
        }
        $PlanObj = New-DryPlan @NewDryPlanParams
        Remove-Variable -Name NewDryPlanParams -ErrorAction Ignore
        
        $ShowDryPlanParams       = @{
            Plan                 = $PlanObj
            Mode                 = 'Plan' 
            ConfigCombo          = $ConfigCombo 
            ShowConfigCombo      = $True
            ShowDeselected       = $ShowDeselected
        }
        Show-DryPlan @ShowDryPlanParams
        Remove-Variable -Name PlanObj -ErrorAction Ignore
    }


    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
    # 
    #   APPLY 
    #   Apply gets the current plan, and executes actions in the correct order. 
    #   If retrying from a previously failed attempt, it continues from the  
    #   failed action
    #
    # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

    if ($Apply) { 
        $PlanStartTime = Get-Date
        $GetDryPlanParams = @{
            PlanFile             = $PlanFile
            ResourceNames        = $Resources
            ExcludeResourceNames = $ExcludeResources
            ActionNames          = $Actions
            ExcludeActionNames   = $ExcludeActions
            BuildOrders         = $BuildOrders
            ExcludeBuildOrders  = $ExcludeBuildOrders
            Phases               = $Phases
            ExcludePhases        = $ExcludePhases
        }
        $PlanObj = Get-DryPlan @GetDryPlanParams -ErrorAction Stop

        $GetDryResourcesParams   = @{
            Path        = $ResourcesFile
            ErrorAction = 'Stop'
        }
        $ResolvedResources = Get-DryCommentedJson @GetDryResourcesParams

        #! Implement only when the new pkmgt module is ready
        if (-not $IgnoreDependencies) {
            if (-not (Test-DryDependenciesHash -Hash $CurrentsObject.dependencies_hash -Dependencies $ProjectMap.dependencies)) {
                ol w 'Run -Init to install dependencies for DryDeploy'
                return
            }
            # check if dependencies for the ModuleConfig are met
            if (-not (Test-DryDependenciesHash -Hash $ConfigCombo.dependencies_hash -Dependencies ((Get-DryRootConfig -Path $ConfigCombo.ModuleConfig.path).dependencies))) {
                ol w 'Run -ModuleInit to install dependencies for your ModuleConfig'
                return
            }
        }
        
        for ($ActionCount = 1; $ActionCount -le $PlanObj.ActiveActions; $ActionCount++ ) {
            Remove-Variable -Name Action -ErrorAction Ignore
            $Action = $PlanObj.Actions | 
            Where-Object { 
                $_.ApplyOrder -eq $ActionCount
            }
            
            if ($Null -eq $Action) {
                throw "Unable to find Action with Order $ActionCount in Plan"
            }

            try {
                if ($Action.Status -eq 'Todo') {
                    $Action.Status = 'Starting'
                    $PlanObj.SaveToFile($PlanFile,$False)
                }
                elseif ($Action.Status -eq 'Failed') {
                    $Action.Status = 'Retrying'
                    $PlanObj.SaveToFile($PlanFile,$False)
                }
                
                Show-DryPlan -Plan $PlanObj -Mode 'Apply' -ConfigCombo $ConfigCombo

                ol i " "
                    ol i "Resource:      [$($Action.ResourceName)]"
                if ($Action.Phase) {
                    ol i "Action:        [$($Action.Action)] - Phase [$($Action.Phase)]"
                }
                else { 
                    ol i "Action:        [$($Action.Action)]"
                }
                ol i " "
                ol i "Description:   $($Action.Description)"
                ol i " "
                ol i " " -h

                # Define the global resource name used in output after the plan has been shown
                New-Variable -Name GlobalResourceName -Value $Action.ResourceName -Scope GLOBAL
                New-Variable -Name GlobalActionName -Value $Action.Action -Scope GLOBAL
                if ($Action.Phase -ge 1) {
                    New-Variable -Name GlobalPhase -Value $Action.Phase -Scope GLOBAL
                }

                # Match up this action with the resource object in $ResolvedResources
                Remove-Variable -Name Resource -ErrorAction Ignore 
                $Resource = $ResolvedResources.Resources | Where-Object { 
                    $_.Resource_Guid -eq $Action.Resource_Guid
                }

                # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                # 
                #   RESOURCE VARIABLES 
                #
                #   Pick up and create any resource variable
                #
                # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

                if ($Configuration.resource_variables) {
                    $ResolveDryVariablesParams = @{
                        Variables              = $Configuration.resource_variables
                        Configuration          = $Configuration
                        VariablesList          = $CommonVariables
                        Resource               = $Resource
                        OutputType             = 'list'
                    }
                    $ResourceVariables = Resolve-DryVariables @ResolveDryVariablesParams
                    Remove-Variable -Name ResolveDryVariablesParams -ErrorAction Ignore  
                }

                $ActionStatus = 'Failed'
                $ActionName = "dry.action.$($Action.Action)"
                ol i @('Action Module/Name',"$ActionName")
                $ActionName | Import-Module -Force -ErrorAction Stop

                $ActionParameters     = @{
                    Action            = $Action 
                    Resource          = $Resource
                    Configuration     = $Configuration
                    ResourceVariables = $ResourceVariables
                }
                # You may call ".\DryDeploy.ps1 -Apply -ActionParams @{'param1'='value1'}" to pass a hashtable
                # of names and values to the action-function if it supports some way of filtering on certain 
                # parts of the configuration, however this params are highly action specific, som the action
                # function will automatically quit after this. 
                if ($ActionParams) {
                    $ActionParameters+=@{'ActionParams'=$ActionParams}
                    $Quit = $true
                }

                # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                #
                #   Execute Action
                #
                # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
            
                $ActionStartTime = Get-Date
                & $ActionName @ActionParameters
                $ActionEndTime = Get-Date
                # No Catch? 
                $ActionStatus = 'Success'

                # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                #
                #   Resolve IP Address
                #   If the Resource uses DHCP, it's current address should be added to the 
                #   Resource in the Resources file so subsequent actions may find it.  
                #   Not ideal, but here we are. Should be included in the classes of core
                #
                # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                if ($Resource.resolved_network.ip_address -eq 'dhcp') {
                    if ($GLOBAL:ResourceIP -match [regex]"^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$") {
                        ol i "IP for DHCP resource '$($Action.ResourceName)'","$($GLOBAL:ResourceIP)"
                        ($ResolvedResources.Resources | Where-Object { $_.resource_guid -eq $Action.resource_guid }).resolved_network.ip_address = "$($GLOBAL:ResourceIP)" 
                        Set-Content -Path $ResourcesFile -Value (ConvertTo-Json -InputObject $ResolvedResources -Depth 50) -Force
                    }
                }
                $GLOBAL:ResourceIP = $null

                # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                #
                #   Step and Quit
                #   
                #   Stepping through, or quitting after each successful step
                #
                # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
                if ($Quit) {
                    $Error.Clear()
                    $LASTEXITCODE = 0
                    break
                }

                if ($Step) {
                    $StepResponse = Read-Host -Prompt "Press ENTER to continue or Q(uit) to quit"
                    if (
                        ($StepResponse -eq 'q') -or
                        ($StepResponse -eq 'quit')
                    ) { 
                        break
                    }
                }
            }
            catch {
                $GLOBAL:ResourceIP = $null
                $ActionEndTime = Get-Date
                $ActionStatus = 'Failed'
                if ($ShowAllErrors) {
                    for ($ec = ($Error.count-1); $ec -ge 0; $ec--) {
                        if ($ec -eq 0) {
                            ol i "The terminating error: " -sh
                            ol i " "
                        }
                        else {
                            ol i "Non-terminating error $ec`:" -sh
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
                else {
                    ol i "The terminating error: " -sh
                    ol i " "
                    Show-DryError -Err $_
                }
                
                if ($Action.Phase) {
                    throw "Failed action: [$($Action.action)] - Phase [$($Action.Phase)]"
                }
                else {
                    throw "Failed action: [$($Action.action)]"
                }
            }
            finally {
                # Remove the global resoure name
                Remove-Variable -Name GlobalIP -ErrorAction Ignore -Scope GLOBAL
                Remove-Variable -Name GlobalResourceName -ErrorAction Ignore -Scope GLOBAL
                Remove-Variable -Name GlobalActionName -ErrorAction Ignore -Scope GLOBAL
                Remove-Variable -Name GlobalPhase -ErrorAction Ignore -Scope GLOBAL
                Remove-Module -Name "dry.action.$($Action.Action)" -ErrorAction Ignore
                
                if (($ActionEndTime) -and ($ActionStartTime)) {
                    [timespan]$ActionSpan = ($ActionEndTime-$ActionStartTime)
                    ol i " " -h
                    ol i " "
                    if ($Action.Phase) {
                        ol i "Action [$($Action.action)] - Phase [$($Action.Phase)] took $($ActionSpan.ToString("dd\:hh\:mm\:ss")) to complete"
                    }
                    else {
                        ol i "Action [$($Action.action)] took $($ActionSpan.ToString("dd\:hh\:mm\:ss")) to complete"
                    }
                    
                    ol i " "
                    ol i "Status: $($ActionStatus.ToUpper())"
                    ol i " "
                }
                $Action.Status = $ActionStatus
                $PlanObj.SaveToFile($PlanFile,$False)
            }
        }
    }
}
catch {
    $PSCmdlet.ThrowTerminatingError($_)
}
finally {
    if ($Apply) {
        # Show the final Plan
        $GetDryPlanParams        = @{
            PlanFile             = $PlanFile
            ResourceNames        = $Resources
            ExcludeResourceNames = $ExcludeResources
            ActionNames          = $Actions
            ExcludeActionNames   = $ExcludeActions
            BuildOrders         = $BuildOrders
            ExcludeBuildOrders  = $ExcludeBuildOrders
            Phases               = $Phases
            ExcludePhases        = $ExcludePhases
        }
        $PlanObj = Get-DryPlan @GetDryPlanParams -ErrorAction Stop
        Show-DryPlan -Plan $PlanObj -Mode 'Apply' -ConfigCombo $ConfigCombo

        [TimeSpan]$PlanSpan = ($(Get-Date)-$PlanStartTime)
        
        #! Should record all separate runs, from the first -Apply, until the Plan reached it's fully completed state
        ol i " "
        ol i "Plan took $($PlanSpan.ToString("dd\:hh\:mm\:ss")) to complete"
        ol i " "
    }
    
    # Reset global Preferences
    $GLOBAL:VerbosePreference = $GlobalVerbosePreference
    $GLOBAL:DebugPreference = $GlobalDebugPreference
    $GLOBAL:ErrorActionPreference = $GlobalErrorActionPreference

    # Reset PSModulePath
    $env:PSModulePath = $OriginalPSModulePath

    # This function will make us popular around the globe...doh! I meant, around our flat earth:
    $GoodByes = @('Goodbye','Adios','Arrivederci','Au Revoir','Adeus','Do Pobachennya')
    ol i "DryDeploy $($GoodByes | Get-Random)" -sh -hchar $DryDeployHeaderChar -air
    ol i " "
    # Remove all DryModules
    foreach ($DryModule in  @((Get-Module | 
        Where-Object { (($_.Name -match "^dry\.action\.") -or ($_.Name -match "^dry\.module\."))}) | 
        Select-Object Name).Name) {
        Get-Module $DryModule | Remove-Module -Verbose:$False -Force -ErrorAction Ignore
    }
    
    $GlobalVariableNames = @(
        'ShowPasswords',
        'SuppressInteractivePrompts',
        'ShowStatus',
        'KeepConfigFiles',
        'RootWorkingDirectory',
        'GlobalPhase',
        'GlobalActionName',
        'GlobalResourceName',
        'EnvConfigName',
        'CredentialsType',
        'Force'
    )
    $CommonVariables.foreach({
        $GlobalVariableNames += $_.Name
    })
     $GlobalVariableNames | ForEach-Object  {
        Remove-Variable -Name "$_" -Scope Global -ErrorAction 'Ignore'
    }
}