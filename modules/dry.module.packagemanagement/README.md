# dry.module.packagemanagement

A PSmodule to
 1. bootstrap package management 
 2. manage package source registrations
 3. install package providers
 4. install packages

## Bootstrapping package management
For some reason, at the time of writing at least, all Windows variants ships with seriously outdated components for proper package management. The exported function `Initialize-DryPackageManagement` performs the bootstrapping.  
- if the Nuget packageprovider version is less than 2.8.5.201, the newest version found is installed. If it is 2.8.5.201 or greater, does nothing
- if the PackageManagement (a.k.a 'OneGet') PowerShell module installed version is less than 1.4.7, the newest version found is installed. If it is 1.4.7 or greater, does nothing
- if Chocolatey ('choco.exe') is not found in the environment's path, latest version is installed. If any version of Chocolatey is installed, does nothing
- if the PowerShell module *Foil* is not found, or it's version is less than 0.1.0, the latest version is installed. If the version 0.1.0 or newer is found, does nothing. Foil is used for managing Chocolatey packages and sources.
- if the PowerShell module *GitAutomation* is not found, or it's version is less than 0.14.0, the latest version is installed. If the version 0.14.0 or newer is found, does nothing. GitAutomation is used for cloning and checkout of Git repositories. 
- if a custom web server FQDN is passed to the function via the RootURL parameter, all resources are tried downloaded from the RootURL, instead of their original internet sources 

## Package Source registration
Register and unregister package sources. Supports the source types:

1. Nuget
1. Chocolatey
1. Git

## Package Installations
Installs packages, using PackageManagement (a.k.a OneGet). Supports packages of the following types: 

- PowerShell modules (nuget)
- Chocolatey packages (nuget)
- Git-repos as PowerShell modules (git, cloned into the system PSModulePath)
- Git-repos (cloned into any folder)
- Windows Roles and Features
- Windows Optional Components
