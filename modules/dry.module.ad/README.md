# dry.module.ad

For in-depth documentation, checkout the [wiki](https://github.com/bjoernf73/dry.module.ad/wiki).

## Features
dry.module.ad is a module for configuration of Active Directory objects, namely
- Creation of OU hierarchies
- Creation of AD groups of any type
- Group nesting (groups' group memberships)
- Rights on AD objects (acl's on any object in any AD naming context)
- GPO imports with migrations
  - native support for backup-GPO's
  - support for *automigrating json-GPOs* 
- GPO links (supports replacement of *lower-versioned-GPO's* with *higher-versioned-GPO's* of versioning formats `v1.2.3` and `v1r2`)
- WMI Filter creation 
- WMI Filter links on GPOs
- AD Schema extensions (from ldf-files) 
- Netlogon files (recursive copy of everything in your configuration's *netlogon* folder to your domain's NETLOGON) 
- Administrative Templates (copies everything in your configuration's *adm_templates* folder to *PolicyDefintions* on SYSVOL) 
- Creation of users
- Users' group memberships 

## Configuration files
Predominantly, `dry.module.ad` takes one or multiple json-files as input, converting the defined objects to configurations in Active Directory. Some configurations are file based (netlogon files, administrative templates, backup- and json-gpos import, and AD schema extensions). 

## Local-run vs Remote-run
You may run the `Import-DryADConfiguration` either 
- locally (local-run) with the privileges of the logged on identity, or 
- remotely (remote-run), meaning in a PSSession to a domain controller (or to any domain member, as long as you configure it to bypass the second-hop-authentication problem).

Remote-run requires you to establish a PSSession to the target, and passing the session to `Import-DryADConfiguration`:
```powershell
@('dry.module.log','dry.module.ad').foreach({
    Import-module -Name $_
})
# The ActiveDirectory module will warn about unable to connect the AD drive - don't mind that.

$cred = Get-Credential -UserName 'dom\admin' -Message 'enter dom\admin`s password'
$sess = New-PSSession -Credential $cred -ComputerName 10.0.5.6

Import-DryADConfiguration -PSSession $sess -ConfigurationPath ..\Some\Folder -VariablesPath ...
```

## Installation
dry.module.ad requires dry.module.log, so 
```
Install-Module -Name dry.module.log 
Install-Module -Name dry.module.ad
```

## Example
The module contains an example configuration in the `example` folder. The example is zipped because backup-gpo's reached the dreaded Windows maximum file path depth of 256 chars. Therefore unzip close to a drive's root, or do `subst z: c:\folder\to\unzip\to` and unzip to z:



<br>

# On DryDeploy
The dry.module.ad module is made for *DryDeploy*, more than it is made for standalone use. It is a submodule of a couple of standard action modules of DryDeploy, namely [dry.action.ad.import](https://github.com/bjoernf73/dry.action.ad.import) and [dry.action.ad.move](https://github.com/bjoernf73/dry.action.ad.move). 

*DryDeploy* aspires to do all aspects of automated deployment and configuration of Windows and Linux resources 
 - *using*, and not *competing with*, frameworks like Desired State Configuration, Terraform, Ansible, SaltStack, and so on. 

Check out the project [here](https://github.com/bjoernf73/DryDeploy), or clone recursively with 
```
git clone https://github.com/bjoernf73/DryDeploy.git --recurse
``` 