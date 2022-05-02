# Create/customize OS templates for any platform
You may use DryDeploy to create images using it's action `packer.run` that in turn uses the great Hashicorp tool *Packer*. Packer has plug-ins for (probably) any cloud or on-prem provider, and let's you put all . , andDryImage uses Packer to create images for your virtual on-prem or cloud platform. It takes a variables json and a configuration directory containing your packer config, and invokes Packer. So why not just use Packer? 

Packer creates your image from a source, and runs whatever commands you want it to run on that OS. DryImage provides a set of functions for that task, so you may specify in data, not in code, the stuff you wanna do. For instance, you may specify, in data, 

- what administrative interfaces to set up (rdp, winrm and ssh)
- what windows update classifications to apply
- what firewall rules to add, optionally removing all default rules, which is always a good idea
- which chocolatey packages to install, with what options, and what PowerShell or cmd post-commands to run for a package (for instance `sc config salt-minion start=disabled`)
- what windows optional features to enable or disable
- what windows capabilities to install or remove
- what Nuget modules to install

Also, DryImage's base-images supply you with base unattend-files for all recent Windows OS's that contain replacement-patterns that will be replaced by values from variables defined in your vars.json. DryImage supplies packer with the unattend during install.

Not enabled in any example, but: you may also instruct DryImage to

- generate an ssh keypair on the image
- curl the public key up to one or multiple git online accounts
- distribute that keypair to the Default account, so all your gits are available immediately after logon to a clone of your image

Needless to say, this functionality should only be used in private development environments.  

## Quickstart - 3 steps

### 1. Clone DryImage

Make sure to clone DryImage recursively using the `--recurse` switch: 
```sh
git clone https://github.com/bjoernf73/DryImage.git --recurse
```

---

### 2. Clone base-images
Also, clone base-images for Lins and Wins. The base-images may be used as is, but you should consider customizing them to meet your requirements.
```
git clone https://github.com/bjoernf73/DryImageConfigs.git
```
To customize, remove the folder `DryImageConfigs\.git` and make that repo your own. Now you may customize the configs to your needs, and check those customizations into your private repository. 

---

### 3. Configure variables
Make a copy of the file `vars.json` in the *Example* folder of `DryImage`. Put outside any repo, preferably on the same level as your *DryImage* and *DryImageConfigs* directories. Note that all values in the file are examples, the product keys are just arbitrary randoms - don't waste time trying to use them. 

The values in *vars.json*'s `variables` node are used in 2 ways: 

  1. All are saved to a temporary file, that is sent to `packer.exe` using the `--var-file` parameter. You may reuse those variables in your packer-config (variable `"some_name": "some_value"` may be used in a packer-json as ``{{user `some_name`}}``.

  1. Each image has a `Config.json` at root describing the files that will be copied to a temporary working directory, like the code below. If a file's `replace: true`, any pattern `###some_name###` in the file will replaced by `some_value`. 

    {
      "display_name": "Ubuntu Server 20.04.3",
      "type": "linux",
      "files": [ 
          {
              "name": "ci-ubuntu.20.04.3.srv-packerconfig.json",
              "type": "json",
              "tag": "packerconfig",
              "replace": false
          },
          {
              "name": "user-data",
              "tag": "http-file",
              "replace": true
          },
          {
              "name": "meta-data",
              "tag": "http-file",
              "replace": false
          }
      ]
    }
---

## Running DryImage
DryImage will test the presence of prerequisites at each run, which are
| # |program |description |
| --- |--- |--- |
| 1 | oscdimg | Packer needs OSDCImg of Windows ADK |
| 2 | chocolatey | Windows without Chocolatey is like hot cocoa without...chocolatey|
| 3 | packer | Hashicorp's Packer is the engine that automates the building of images | 

If either is not installed, or not in path, DryImage will try to install them. This will fail if you are not elevated. If so, elevate PowerShell (right-click and 'Run as Adminstrator'), and run 
```
.\DryImage.ps1
```

---
If you need help (admit it - you do), run `man`:
```
man .\DryDeploy
```

---

If you have a directory and file structure where `DryImage`, `DryImageConfigs` and `vars.json` are on the same level, like
```
PS>dir | select mode,fullname

Mode   FullName
----   --------
d----- C:\Some\dir\DryImage
d----- C:\Some\dir\DryImageConfigs
-a---- C:\Some\dir\vars.json
```
all components are in their default locations, so you may simply run
```
.\DryImage.ps1
```
for an interactive session. If you your stuff is located elsewhere, run
```
.\DryImage.ps1 -vars ..\path\to\vars.json -Configs ..\path\to\Configs\directory 
```

---

Upon error, packer will delete an image. If you wanna keep, use the `-KeepOnError` switch.
```
.\DryImage.ps1 -KeepOnError
```

---

All files denoted in an image's `Config.json` will be copied to a temporary location (look in `$($env:Appdata)\DryImage`). If you don't want those temporary working files to be deleted at the end of a run, use `-KeepConfigFiles`. 
```
.\DryImage -KeepConfigFiles
```
---

If you wanna force overwrite of an existing image, `-Force`.
```
.\DryImage -Force
```

---

If you wanna run automatically (non-interactive), specify the image indexes using the `-Images` parameter. Run an interactive session first to see the mapping between images and index numbers. 
```
.\DryImage -Images 2,3,4
```
