Using Namespace System.DirectoryServices.ActiveDirectory
#Using Module GPRegistryPolicyParser

class BaseSettings {
    [string]$ObjectType
}

class GroupPolicy : BaseSettings {
    [string]$Name
    [LinkTarget[]]$Linktargets
    [bool]$ComputerSettingsEnabled
    [bool]$UserSettingsEnabled
    [WMIFilter]$WMIFilter
    [string]$Permissions
    [PolicySettings]$PolicySettings
    [string]$gPCMachineExtensionNames
    [string]$gPCUserExtensionNames

    GroupPolicy () {
        $this.ObjectType = "GroupPolicy"
        $this.PolicySettings = [PolicySettings]::new()
    }

    GroupPolicy (
        [string]$Name
    ) {
        $this.Name = $Name
        $this.ObjectType = "GroupPolicy"
        $this.PolicySettings = [PolicySettings]::new()
    }
    
    # Get GPO from AD and save it to json-file all in one go
    GroupPolicy (
        [string]$Name,
        [bool]$GetLinks,
        [string]$FileName
    ) {
        $this.ObjectType = "GroupPolicy"
        $this.PolicySettings = [PolicySettings]::new()
        $this.GetPolicyFromAD($Name, $GetLinks)
        $this.WritePolicyToJson($FileName)
    }

    # Read json-file and import to AD in one operation
    GroupPolicy (
        [string]$FileName,
        [hashtable]$Replacements,
        [bool]$Overwrite,
        [bool]$Backup,
        [bool]$RemoveLink
    ) {
        $this.ObjectType = "GroupPolicy"
        $this.PolicySettings = [PolicySettings]::new()
        $this.GetPolicyFromJson($FileName, $Replacements, $false)
        $this.WritePolicyToAD($Overwrite, $Backup, $RemoveLink)
    }


    [void] hidden IncrementVersion(
        [string]$id,
        [string]$DomainController,
        [string]$DomainFQDN,
        [uint32]$IncrementBy
    ) {
        $Utils = [Utils]::new()
        $properties = @("gPCFileSysPath","versionNumber")
        $Retry = $true
        $Count = 0
        $gpContainer = $null
        do {
            $gpContainer = Get-ADObject -LDAPFilter "(&(CN={$id})(objectclass=groupPolicyContainer))" -properties $properties -Server $DomainController
            if ($gpContainer) {
                $Retry = $false
            } else {
                Start-Sleep -seconds 1
                $count++
                if ($count -gt 60) {
                    throw "Failed to get CN={$id} after 60 retries."
                }
            }
        } while ($Retry)
    
        $version = [uint32]$gpContainer.versionNumber
        $inifilepath = "\\$DomainController\SYSVOL\$DomainFQDN\Policies\{$id}\GPT.INI"
        $version=$version+$IncrementBy
    
        # first update ad
        try {
            Set-ADObject -identity $gpContainer.distinguishedname -Replace @{versionNumber=$version} -ErrorAction Stop -Server $DomainController
        } catch {}
    
        # Then update filesystem (SYSVOL)
        try {
            $count = 0
            Do {
                Start-Sleep -seconds 1
                $count++
                if ($count -gt 60) {
                    throw "Timeout waiting for the creation of '$inifilepath'"
                }
                
            } while (!(Test-Path -path $inifilepath))
            
            $inifile = $Utils.GetIniFile($inifilepath)
            $inifile.General.Version = $version
            $Utils.WriteIniFile($inifilepath, $inifile, 'UTF8NoBOM', $false, $true) # FilePath, InputObject, Encoding, Append, Force
        } catch {
            throw $_
        }
    }

    #[void] hidden AddLink() { }
    #[void] hidden ApplyWMIFilter() { }
    #[void] hidden ApplyGPPermissions() { }

    [void]GetPolicyFromJson(
        [string]$FileName,
        [hashtable]$Replacements,
        [bool]$IsComparing
    ) {
        $AllowedValueTypes = @('REG_MULTI_SZ', 'REG_SZ', 'REG_DWORD', 'REG_QWORD', 'REG_NONE')
        #$AllowedTrusteeTypes = @('User', 'Group', 'Computer')
        $Utils = [Utils]::new()
        $defaultNamingContext = (Get-ADRootDSE).defaultNamingContext
        
        # Read file. If $Replacements, replace
        if ($Replacements -and ($Replacements.count -gt 0)) {
            $jsonRaw = Get-Content -Path $FileName -Encoding Default -Raw -ErrorAction Stop
            foreach ($key in $Replacements.Keys) {
                # $jsonRaw = $jsonRaw.Replace($key,$Replacements["$Key"]) # <-- case sensitive, so ##domainNB## won't match ##DomainNB##
                $jsonRaw = $jsonRaw -replace $key,$Replacements["$Key"]  # <-- case in-sensitive by default, so ##domainNB## will match ##DomainNB##

            }
            $jsonImport = $jsonRaw | ConvertFrom-Json -ErrorAction Stop
        } else {
            $jsonImport = Get-Content -Path $FileName -Encoding Default -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        }

        $this.Name = $jsonImport.Name
        $this.ComputerSettingsEnabled = $jsonImport.ComputerSettingsEnabled
        $this.UserSettingsEnabled = $jsonImport.UserSettingsEnabled
        $this.gPCMachineExtensionNames = $jsonImport.gPCMachineExtensionNames
        $this.gPCUserExtensionNames = $jsonImport.gPCUserExtensionNames
        
        ## GPO Comments
        if ($jsonImport.PolicySettings.GPOComments) {
            foreach ($item in $jsonImport.PolicySettings.GPOComments) {
                #$itemreplaced = $Utils.ReplaceNames($item,$false)
                $this.PolicySettings.GPOComments += $item #$itemreplaced
            }
        }

        ## AdmTemplates Machine Settings Comments
        if ($jsonImport.PolicySettings.MachineComments) {
            foreach ($item in $jsonImport.PolicySettings.MachineComments) {
                $this.PolicySettings.MachineComments += $item 
            }
        }

        ## AdmTemplates User Settings Comments
        if ($jsonImport.PolicySettings.UserComments) {
            foreach ($item in $jsonImport.PolicySettings.UserComments) {
                $this.PolicySettings.UserComments += $item 
            }
        }

        ## Registry settings ##
        if ($jsonImport.PolicySettings.RegistrySettings) {
            foreach ($RegistrySetting in $jsonImport.PolicySettings.RegistrySettings) {
                # Validate input. Make sure correct value types are used. Allowed values are REG_SZ, REG_DWORD, REG_QWORD
                if ($AllowedValueTypes -icontains $RegistrySetting.ValueType) {
                    # Replace any Replace####[names]
                    #$RegistrySetting.ValueName = $Utils.ReplaceNames($RegistrySetting.ValueName,$false)
                    try {
                        $this.PolicySettings.RegistrySettings += [RegistrySetting]$RegistrySetting
                    } catch {
                        throw "Verify registry setting properties. Must include the following properties: Target, KeyName, ValueType, ValueName and ValueData"
                    }
                } else {
                    Write-Warning "Validation error: Registry valuetype = $($RegistrySetting.ValueType) is not allowed. Use one of the following types: $AllowedValueTypes"
                }
            }
        }

        ## Audit settings ##
        if ($jsonImport.PolicySettings.AuditSettings) {
            foreach ($AuditSetting in $jsonImport.PolicySettings.AuditSettings) {
                try {
                    $this.PolicySettings.AuditSettings += [AuditSetting]$AuditSetting
                } catch {
                    throw "Failed to import audit settings from json - $($_.Exception.Message)"
                }
            }
        }

        ## Security template ##
        if ($jsonImport.PolicySettings.SecurityTemplate) {
            foreach ($item in $jsonImport.PolicySettings.SecurityTemplate) {
                #$itemreplaced = $Utils.ReplaceNames($item,$false)
                $this.PolicySettings.SecurityTemplate += $item #$itemreplaced
            }
        }

        ## Folder Redirection version Zero (user only-setting) - this file seems to always be there - but always only 3 blank lines ##
        if ($jsonImport.PolicySettings.FolderRedirection) {
            foreach ($item in $jsonImport.PolicySettings.FolderRedirection) {
                # $itemreplaced = $Utils.ReplaceNames($item,$true)
                # $this.PolicySettings.FolderRedirection += $itemreplaced
                $this.PolicySettings.FolderRedirection += $item
            }
        }
        
        ## Folder Redirection version One (user only-setting) ##
        if ($jsonImport.PolicySettings.FolderRedirection1) {
            foreach ($item1 in $jsonImport.PolicySettings.FolderRedirection1) {
                # $itemreplaced1 = $Utils.ReplaceNames($item1,$true)
                # $this.PolicySettings.FolderRedirection1 += $itemreplaced1
                $this.PolicySettings.FolderRedirection1 += $item1
            }
        }

        ## Scripts ##
        if ($jsonImport.PolicySettings.Scripts) {
            foreach ($Script in $jsonImport.PolicySettings.Scripts) {
                $this.PolicySettings.Scripts = [Script[]]$jsonImport.PolicySettings.Scripts
            }
        }

        ## GPP ##
        if ($jsonImport.PolicySettings.GroupPolicyPreferences) {
            foreach ($GPP in $jsonImport.PolicySettings.GroupPolicyPreferences) {
                $XmlContent = [xml]$GPP.XmlContent
                $XmlContent = $Utils.ReplaceXmlValues($XmlContent, $IsComparing)
                $XmlContent = $Utils.FormatXml($XmlContent, 4)
                #foreach ($line in $XmlContent) {
                #    $line = $Utils.ReplaceNames($line,$false)
                #}
                $GPP.XmlContent = $XmlContent
                $this.PolicySettings.GroupPolicyPreferences += [GroupPolicyPreference]$GPP
            }
        }

        # Permissions
        #$this.Permissions = $Utils.ReplaceNames($jsonImport.Permissions,$false)
        $this.Permissions = $jsonImport.Permissions

        # Links
        foreach ($LinkTarget in $jsonImport.LinkTargets) {
            $Target = $LinkTarget.Target -ireplace '####defaultNamingContext####', $defaultNamingContext
            $this.LinkTargets += [LinkTarget]::new($Target, $LinkTarget.LinkOrder, $LinkTarget.LinkPolicy, $LinkTarget.LinkEnabled, $LinkTarget.Enforced) # Target, LinkOrder, LinkPolicy, LinkEnabled, Enforced
        }

        # WMI filter
        if ($jsonImport.WMIFilter) {
            $this.WMIFilter = [WMIFilter]::new($jsonImport.WMIFilter.Name, $jsonImport.WMIFilter.Query, $jsonImport.WMIFilter.Description)
        }
    }

    [void]GetPolicyFromAD(
        [string]$Name,
        [bool]$GetLinks
    ) {
        $Utils = [Utils]::new()
        $this.Name = $Name
        
        Import-Module -Name GPRegistryPolicyParser -ErrorAction Stop -WarningAction Continue
        
        $GPO = Get-GPO -Name $Name
        $PolicyGuid = "{$($GPO.Id.Guid)}"

        $this.ComputerSettingsEnabled = $GPO.Computer.Enabled
        $this.UserSettingsEnabled = $GPO.User.Enabled

        $Domain = [Domain]::GetComputerDomain().Name
        $defaultNamingContext = (Get-ADRootDSE).defaultNamingContext
        $PolicyServerId = (Get-CertificateEnrollmentPolicyServer -Scope All -Context Machine).Id

        ## GPO Comments
        $GPOCommentsPath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\GPO.cmt"
        if ((Test-Path -Path $GPOCommentsPath)) {
            try {
                $GPOCommentContent = Get-Content -Path $GPOCommentsPath -Encoding unicode -ErrorAction Stop
            } catch {
                throw "Failed to read GPO.cmt - $($_.Exception.Message)"
            }
            $arrGPOCommentContent = [string[]]$GPOCommentContent
            $this.PolicySettings.GPOComments = $arrGPOCommentContent
        }

        ## AdmTemplates Machine Settings Comments
        $MachineCommentsPath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\Machine\comment.cmtx"
        if ((Test-Path -Path $MachineCommentsPath)) {
            try {
                $MachineCommentsContent = Get-Content -Path $MachineCommentsPath -Encoding UTF8 -ErrorAction Stop
            } catch {
                throw "Failed to read Machine\comment.cmtx - $($_.Exception.Message)"
            }
            $arrMachineCommentsContent = [string[]]$MachineCommentsContent
            $this.PolicySettings.MachineComments = $arrMachineCommentsContent
        }

        ## AdmTemplates User Settings Comments
        $UserCommentsPath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\User\comment.cmtx"
        if ((Test-Path -Path $UserCommentsPath)) {
            try {
                $UserCommentsContent = Get-Content -Path $UserCommentsPath -Encoding UTF8 -ErrorAction Stop
            } catch {
                throw "Failed to read User\comment.cmtx - $($_.Exception.Message)"
            }
            $arrUserCommentsContent = [string[]]$UserCommentsContent
            $this.PolicySettings.UserComments = $arrUserCommentsContent
        }

        
        ## Registry settings - Machine ##
        $PolFilePath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\Machine\Registry.pol"
        if ((Test-Path -Path $PolFilePath)) {
            # Machine policy settings found. Try to read all settings.
            try {
                #$this.PolicySettings = [PolicySettings]::new()
                $ParseResult = Parse-PolFile -Path $PolFilePath
                foreach ($item in $ParseResult) {
                    $item.ValueData = $Utils.ReplaceSIDs($item.ValueData)
                    $item.ValueData = $item.ValueData -ireplace $PolicyServerId, '####PolicyServerId####'
                    $RegSetting = [RegistrySetting]::new('Machine', $item.KeyName, $item.ValueType, $item.ValueName, $item.ValueData)
                    $this.PolicySettings.Add($RegSetting)
                }
            } catch {
                throw "Failed to parse machine registry settings - $($_.Exception.Message)"
            }

        }

        ## Registry settings - User ##
        $PolFilePath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\User\Registry.pol"
        if ((Test-Path -Path $PolFilePath)) {
            # Machine policy settings found. Try to read all settings.
            try {
                $ParseResult = Parse-PolFile -Path $PolFilePath
                foreach ($item in $ParseResult) {
                    $item.ValueData = $Utils.ReplaceSIDs($item.ValueData)
                    $RegSetting = [RegistrySetting]::new('User', $item.KeyName, $item.ValueType, $item.ValueName, $item.ValueData)
                    $this.PolicySettings.Add($RegSetting)
                }
            } catch {
                throw "Failed to parse user registry settings - $($_.Exception.Message)"
            }
        }


        ## Audit settings ##
        $AuditPath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\Machine\Microsoft\Windows NT\Audit\audit.csv"
        if ((Test-Path -Path $AuditPath)) {
            try {
                $AuditCSV = Import-Csv -Path $AuditPath -Delimiter "," -Encoding Default
            } catch {
                throw "Failed to read audit.csv - $($_.Exception.Message)"
            }

            foreach ($item in $AuditCSV) {
                try {
                    # Machine Name,Policy Target,Subcategory,Subcategory GUID,Inclusion Setting,Exclusion Setting,Setting Value
                    $AuditSetting = [AuditSetting]::new($item.{Machine Name}, $item.{Policy Target}, $item.Subcategory, $item.{SubCategory GUID}, $item.{Inclusion Setting}, $item.{Exclusion Setting}, $item.{Setting Value}) 
                    $this.PolicySettings.Add($AuditSetting)
                } catch {
                    throw "Failed to add audit settings - $($_.Exception.Message)"
                }
            }
        }

        ## Security template ##
        $SecurityTemplatePath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf"
        if ((Test-Path -Path $SecurityTemplatePath)) {
            try {
                $FileContent = Get-Content -Path $SecurityTemplatePath -ErrorAction Stop
            } catch {
                throw "Failed to read GptTeml.inf - $($_.Exception.Message)"
            }
            $arrFileContent = [string[]]$FileContent
            $Utils = [Utils]::new()
            for ($i = 0; $i -lt $arrFileContent.Count; $i++) {
                $arrFileContent[$i] = $Utils.ReplaceSIDs($arrFileContent[$i])
            }
            $this.PolicySettings.SecurityTemplate = $arrFileContent
        }

        ## Folder Redirection version Zero (user only-setting) - this file seems to always be there - but always empty ##
        $FolderRedirectionPath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\User\Documents & Settings\fdeploy.ini"
        if ((Test-Path -Path $FolderRedirectionPath)) {
            try {
                $FRContent = Get-Content -Path $FolderRedirectionPath -ErrorAction Stop
            } catch {
                throw "Failed to read fdeploy.ini and/or fdeploy.ini - $($_.Exception.Message)"
            }

            $arrFRContent = [string[]]$FRContent
            $Utils = [Utils]::new()
            for ($i = 0; $i -lt $arrFRContent.Count; $i++) {
                $arrFRContent[$i] = $Utils.ReplaceSIDs($arrFRContent[$i])
            }
            $this.PolicySettings.FolderRedirection = $arrFRContent
        }

        ## Folder Redirection version One (user only-setting) ##
        $FolderRedirectionPath1 = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\User\Documents & Settings\fdeploy1.ini"
        if ((Test-Path -Path $FolderRedirectionPath1)) {
            try {
                $FRContent1 = Get-Content -Path $FolderRedirectionPath1 -ErrorAction Stop
            } catch {
                throw "Failed to read fdeploy.ini and/or fdeploy1.ini - $($_.Exception.Message)"
            }

            $arrFRContent1 = [string[]]$FRContent1
            $Utils = [Utils]::new()
            for ($i = 0; $i -lt $arrFRContent1.Count; $i++) {
                $arrFRContent1[$i] = $Utils.ReplaceSIDs($arrFRContent1[$i])
            }
            $this.PolicySettings.FolderRedirection1 = $arrFRContent1
        }

        ## Scripts ##
        $GPSource = @('Machine', 'User')
        foreach ($source in $GPSource) {
            $ScriptsPath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\$source\Scripts"
            if ((Test-Path -Path $ScriptsPath)) {
                $NewScript = [Script]::new()
                $NewScript.Target = $source
                
                # Read psscripts.ini
                if ((Test-Path -Path $ScriptsPath\psscripts.ini)) {
                    $NewScript.PSScriptsIni = $Utils.GetIniFile("$ScriptsPath\psscripts.ini")
                }

                # Read scripts.ini
                if ((Test-Path -Path $ScriptsPath\scripts.ini)) {
                    $NewScript.ScriptsIni = $Utils.GetIniFile("$ScriptsPath\scripts.ini")
                }

                # Read scripts from subfolders. Possible subfolders are Shutdown, Startup, Logon and Logoff
                $ScriptFolders = Get-ChildItem -Path $ScriptsPath -Directory -Force
                foreach ($folder in $ScriptFolders) {
                    $FoundScripts = Get-ChildItem -Path $folder.FullName -File -Force
                    foreach ($FoundScript in $FoundScripts) {
                        $NewScriptFile = [ScriptFile]::new()
                        $NewScriptFile.Type = $folder.BaseName
                        $NewScriptFile.Name = $FoundScript.Name
                        $NewScriptFile.Content = Get-Content -Path $FoundScript.FullName -Encoding Default -ErrorAction Stop
                        $NewScript.ScriptFiles += $NewScriptFile
                    }
                }

                $this.PolicySettings.Scripts += $NewScript
            }
        }

        ## GPP ##
        $GPSource = @('Machine', 'User')
        foreach ($source in $GPSource) {
            $GPPPath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\$source\Preferences"
            if ((Test-Path -Path $GPPPath)) {
                $Folders = Get-ChildItem -Path $GPPPath -Directory -Force
                foreach ($Folder in $Folders) {
                    $GPP = [GroupPolicyPreference]::new()
                    $GPP.Type = $Folder.Name
                    $GPP.Target = $source
                    
                    $Files = Get-ChildItem -Path $Folder.FullName -File -Force
                    foreach ($File in $Files) {
                        $GPP.XmlFileName = $File.Name
                        try {
                            $Xml = [xml](Get-Content -Path ($File.FullName) -Encoding Default -ErrorAction Stop)
                            $XmlContent = $Utils.FormatXml($Xml, 4)

                            # Replace any SIDs in xml
                            for ($XmlCi = 0; $XmlCi -lt $XmlContent.count; $XmlCi++) {
                                $XmlContent[$XmlCi] = $Utils.ReplaceSIDs("$($XmlContent[$XmlCi])")
                            }

                            $GPP.XmlContent = $XmlContent
                        } catch {
                            throw "Failed to get GGP file $($Folder.Name).xml - $($_.Exception.Message)"
                        }
                        
                        $this.PolicySettings.GroupPolicyPreferences += $GPP
                    }
                }
            }
        }


        # Get Client side extensions
        $gpcObject = Get-ADObject -Filter "ObjectClass -eq 'groupPolicyContainer' -and Name -eq '$PolicyGuid'" -Properties gPCMachineExtensionNames,gPCUserExtensionNames
        if ($gpcObject) {
            # Get Client Side Extensions
            if ($gpcObject.gPCMachineExtensionNames) {
                $this.gPCMachineExtensionNames = $gpcObject.gPCMachineExtensionNames
            }

            if ($gpcObject.gPCUserExtensionNames) {
                $this.gPCUserExtensionNames = $gpcObject.gPCUserExtensionNames
            }

            # Get permissions. This includes security filtering AND delegation
            $acl = Get-Acl "AD:$($gpcObject.DistinguishedName)"
            $sddl = $acl.sddl
            $sddl = $utils.ReplaceSIDs($sddl)
            $this.Permissions = $sddl
        }

        # Get all links with link order
        if ($GetLinks) {
            $dn = $gpcObject.distinguishedName
            $AllLinkLocations = @(Get-ADObject -Filter "(objectClass -eq 'organizationalUnit' -or objectClass -eq 'domain' -or objectClass -eq 'site') -and gpLink -like '*$dn*'" -Properties gPLink)
            $AllLinkLocations += Get-ADObject -Filter "objectClass -eq 'site' -and gpLink -like '*$dn*'" -SearchBase "CN=Sites,$((Get-ADRootDSE).configurationNamingContext)" -Properties gPLink

            foreach ($item in $AllLinkLocations) { 
                $dn = $item.distinguishedName -ireplace $defaultNamingContext,'####defaultNamingContext####'
                $arrPolicies = $item.gPLink.Split('][', [System.StringSplitOptions]::RemoveEmptyEntries)

                $LinkOrder = 0
                $LinkPolicy = $false
                $LinkEnabled = $false
                $Enforced = $false
                for ($i = 0; $i -lt $arrPolicies.Count; $i++) {
                    if ($arrPolicies[$i] -match $PolicyGUID) {
                        $LinkOrder = $i + 1
                        
                        # 0 = Enabled
                        # 1 = Disabled
                        # 2 = Enabled + Enforced
                        # 3 = Disabled + Enforced
                        $Status = $arrPolicies[$i].Split(';')[1]
                        switch ($Status) {
                            0 {
                                $LinkPolicy = $true
                                $LinkEnabled = $true
                                $Enforced = $false
                            }
                            1 {
                                $LinkPolicy = $true
                                $LinkEnabled = $false
                                $Enforced = $false
                            }
                            2 {
                                $LinkPolicy = $true
                                $LinkEnabled = $true
                                $Enforced = $true
                            }
                            3 {
                                $LinkPolicy = $true
                                $LinkEnabled = $false
                                $Enforced = $true
                            }
                        }
                    }
                }
                $this.LinkTargets += [LinkTarget]::new($dn, $LinkOrder, $LinkPolicy, $LinkEnabled, $Enforced) # Target, LinkOrder, LinkPolicy, LinkEnabled, Enforced
            }
        }

        # Get WMI filter
        if ($GPO.WMIFilter) {
            $WMIFilterObject = Get-ADObject -Filter "objectClass -eq 'msWMI-Som' -and msWMI-Name -eq '$($GPO.WMIFilter.Name)'" -Properties msWMI-Parm1,msWMI-Parm2 -ErrorAction SilentlyContinue
            $this.WMIFilter = [WMIFilter]::new($GPO.WMIFilter.Name, $WMIFilterObject.'msWMI-Parm2', $WMIFilterObject.'msWMI-Parm1') # Name, Query, Description
        } else {
            $this.WMIFilter = $null
        }
    }

    [void]WritePolicyToJson(
        $FileName
    ) {
        try {
            $this | ConvertTo-Json -Depth 10 | Out-File -FilePath $FileName -Encoding default
        } catch {
            throw $_
        }
    }
    
    [void]WritePolicyToAD(
        [bool]$Overwrite,
        [bool]$Backup,
        [bool]$RemoveLink,
        [bool]$DoNotLinkGPO,
        [string]$DomainController
    ) {
        $Utils = [Utils]::new()
        $Domain = [Domain]::GetComputerDomain().Name
        $defaultNamingContext = (Get-ADRootDSE).defaultNamingContext
        $PolicyServerId = (Get-CertificateEnrollmentPolicyServer -Scope All -Context Machine).Id
        
        # Does it exist a GPO with the same name?
        $GPO = Get-GPO -Name $this.Name -ErrorAction SilentlyContinue -Server $DomainController
        if ($GPO) {
            # Yes, it exists
            # What to do? Quit, delete or rename and disable link, then create a new GPO.

            if (!$Overwrite) { 
                return 
            }

            if ($Backup) {
                # Disable link
                # First, find all OUs where the GPO is linked.
                $LinkedOUs = @()
                $AllOUs = Get-ADObject -Filter "objectClass -eq 'organizationalUnit' -or objectClass -eq 'domain' -or objectClass -eq 'site'" -Properties gPLink -Server $DomainController
                $AllOUs += Get-ADObject -Filter "objectClass -eq 'site'" -SearchBase "CN=Sites,$((Get-ADRootDSE).configurationNamingContext)" -Properties gPLink -Server $DomainController

                for ($i = 0; $i -lt $AllOUs.Count; $i++) {
                    $gPLink = $AllOUs[$i].gPLink
                    
                    if ($gPLink) {
                        $arrGPLink = @($gPLink.Split('][',[System.StringSplitOptions]::RemoveEmptyEntries))

                        foreach ($item in $arrGPLink) {
                            if ($item -imatch $GPO.Path) { 
                                $LinkedOUs += $AllOUs[$i].distinguishedName
                            }
                        }
                    }
                }

                foreach ($item in $LinkedOUs) {
                    try {
                        if ($RemoveLink) {
                            Remove-GPLink -Name $this.Name -Target $item -Confirm:$false -Server $DomainController -ErrorAction Stop
                        } else {
                            Set-GPLink -Name $this.Name -Target $item -LinkEnabled No -Server $DomainController -ErrorAction Stop
                        }
                    } catch {
                        throw $_
                    }
                }

                # Rename GPO
                try {
                    Rename-GPO -Name $this.Name -TargetName "$($this.Name) - Backup $(Get-Date -Format 'yyyy-MM-dd hh:mm')" -Server $DomainController -ErrorAction Stop
                } catch {
                    throw $_
                }
            } else {
                # No backup specified. Delete the old GPO.
                try {
                    Remove-GPO -Name $this.Name -Server $DomainController -Confirm:$false -ErrorAction Stop
                } catch {
                    throw "Failed to delete GPO $($this.Name) - $($_.Exception.Message)"
                }
            }
        } else {
            # No, it does NOT exist. Safe to continue.
        }

        try {
            $GPO = New-GPO -Name $this.Name -Server $DomainController -ErrorAction Stop
            $PolicyGuid = "{$($GPO.Id.Guid)}"
        } catch {
            # Something failed
            throw $_
        }

        # Apply GPO Comments
        if ($this.PolicySettings.GPOComments) {
             # The file can contain no more than 2047 carachters, where each line break counts as 2 (\r\n)
            if ($Utils.CommentInSpec($this.PolicySettings.GPOComments)) {
                $GPOCommentsPath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\GPO.cmt"
                
                try {
                    $this.PolicySettings.GPOComments | Out-File -FilePath $GPOCommentsPath -Encoding unicode
                } catch {
                    throw "Failed to save GPO.cmt - $($_.Exception.Message)"
                }
            }
            else {
                Write-Warning "The GPO Comment section may only contain 2047 carachters (new line counts 2)"
                throw "The GPO Comment section may only contain 2047 carachters (new line counts 2)"
            } 
        }

        # Apply Administrative Templates Machine Settings Comments
        if ($this.PolicySettings.MachineComments) {
            $MachineCommentsPath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\Machine\comment.cmtx"
            try {
                $this.PolicySettings.MachineComments | Out-File -FilePath $MachineCommentsPath -Encoding UTF8
            } catch {
                throw "Failed to save Machine\comment.cmtx - $($_.Exception.Message)"
            } 
        }

       # Apply Administrative Templates User Settings Comments
       if ($this.PolicySettings.UserComments) {
            $UserCommentsPath = "\\$($Domain)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\User\comment.cmtx"
            try {
                $this.PolicySettings.UserComments | Out-File -FilePath $UserCommentsPath -Encoding UTF8
            } catch {
                throw "Failed to save User\comment.cmtx - $($_.Exception.Message)"
            } 
        }
        
        # Apply registry settings if specified
        if ($this.PolicySettings.RegistrySettings) {
            # Registry settings found in policy. Starting to apply them.

            Import-Module -Name GPRegistryPolicyParser -ErrorAction Stop -WarningAction Continue
        
            $MachinePolFileExists = $false
            $UserPolFileExists = $false
            $arrMachinePolicies = @()
            $arrUserPolicies = @()
            $polMachinePath = $null
            $polUserPath = $null

            foreach ($setting in $this.PolicySettings.RegistrySettings) {
                switch ($Setting.Target.ToLower()) {
                    'machine' {
                        $polMachinePath = "\\$($DomainController)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\Machine\Registry.pol"

                        if ((Test-Path -Path $polMachinePath) -eq $false -and $MachinePolFileExists -eq $false) {
                            Create-GPRegistryPolicyFile -Path $polMachinePath
                            $MachinePolFileExists = $true
                        }
                    }
                    'user' {
                        $polUserPath = "\\$($DomainController)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\User\Registry.pol"

                        if ((Test-Path -Path $polUserPath) -eq $false -and $UserPolFileExists -eq $false) {
                            Create-GPRegistryPolicyFile -Path $polUserPath
                            $UserPolFileExists = $true
                        }
                    }
                    default { throw 'Wrong Target type. Must be Machine or User.' }
                }

                $RegSettings = @{}
                $RegSettings.Add("keyName",$setting.KeyName)
                $RegSettings.Add("valueType",$setting.ValueType)
                if ($Null -ne $setting.ValueName) 
                { 
                    if ($Setting.ValueName.Length -eq 1) {
                        if (([byte][char]$setting.ValueName) -ne 0) {
                            $RegSettings.Add("valueName",$setting.ValueName)     
                        } else {
                            $RegSettings.Add("valueName","")
                        }
                    } else {
                        $RegSettings.Add("valueName",$setting.ValueName) 
                    }
                }

                if ($Null -ne $setting.ValueData) {
                    $ValueData = $null
                    switch ($setting.ValueType.ToLower()) {
                        "reg_dword" { $ValueData = [uint32]$Setting.ValueData }
                        "reg_qword" { $ValueData = [uint64]$Setting.ValueData }
                        default { 
                            $ValueData = $Utils.ReplaceNames($Setting.ValueData,$false)
                            $ValueData = $ValueData -ireplace '####PolicyServerId####', $PolicyServerId
                        }
                        
                    }
                    
                    $Regsettings.Add("valueData", $ValueData)
                }
                    
                if ($setting.Target -imatch 'machine') { $arrMachinePolicies += New-GPRegistryPolicy @RegSettings }
                if ($setting.Target -imatch 'user') { $arrUserPolicies += New-GPRegistryPolicy @RegSettings }
            }

            # Apply machine policy
            if ($polMachinePath) {
                try {
                    Append-RegistryPolicies -Path $polMachinePath -RegistryPolicies $arrMachinePolicies
                } catch {
                    Write-Error "Failed to set machine settings - $($_.Exception.Message)"
                }
            }

            # Apply machine policy
            if ($polUserPath) {
                try {
                    Append-RegistryPolicies -Path $polUserPath -RegistryPolicies $arrUserPolicies
                } catch {
                    Write-Error "Failed to set user settings - $($_.Exception.Message)"
                }
            }
        }

        # Audit
        if ($this.PolicySettings.AuditSettings) {
            $AuditPath = "\\$($DomainController)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\Machine\Microsoft\Windows NT\Audit"
            if ( (Test-Path -Path $AuditPath) -eq $false ) { New-Item -Path $AuditPath -ItemType Directory  }
            
            # The ObjectType property is meta information, not part of audit.csv
            $AuditFileContent = $this.PolicySettings.AuditSettings | 
            Select-Object -Property * -ExcludeProperty ObjectType | 
            ConvertTo-Csv -NoTypeInformation -Delimiter "," | 
            foreach-Object { $_.Replace('"', '') } 
            
            try {
                $AuditFileContent | Out-File -FilePath $AuditPath\audit.csv -Encoding utf8 -ErrorAction Stop
            } catch {
                throw "Failed to save audit.csv - $($_.Exception.Message)"
            }
        }

        # Security Template
        if ($this.PolicySettings.SecurityTemplate) {
            $SecPath = "\\$($DomainController)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\Machine\Microsoft\Windows NT\SecEdit"
            if ( (Test-Path -Path $SecPath) -eq $false ) { New-Item -Path $SecPath -ItemType Directory  }

            # Replace names with SIDs
            for ($i = 0; $i -lt $this.PolicySettings.SecurityTemplate.Count; $i++) {
                $this.PolicySettings.SecurityTemplate[$i] = $Utils.ReplaceNames($this.PolicySettings.SecurityTemplate[$i],$false)
            }
            #foreach ($line in $this.PolicySettings.SecurityTemplate) {
            #    $line = $Utils.ReplaceNames($line,$false)
            #}

            try {
                $this.PolicySettings.SecurityTemplate | Out-File -FilePath $SecPath\GptTmpl.inf -Encoding default
            } catch {
                throw "Failed to save GptTempl.inf - $($_.Exception.Message)"
            }
        }

        # Folder Redirection v Zero
        if ($this.PolicySettings.FolderRedirection) {
            $FRPath = "\\$($DomainController)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\User\Documents & Settings"
            if ( (Test-Path -Path $FRPath) -eq $false ) { New-Item -Path $FRPath -ItemType Directory  }

            # Replace names with lower-cased-SIDs
            for ($i = 0; $i -lt $this.PolicySettings.FolderRedirection.Count; $i++) {
                $this.PolicySettings.FolderRedirection[$i] = $Utils.ReplaceNames($this.PolicySettings.FolderRedirection[$i],$true)
            }

            try {
                $this.PolicySettings.FolderRedirection | Out-File -FilePath $FRPath\fdeploy.ini -Encoding unicode
            } catch {
                throw "Failed to save fdeploy.ini - $($_.Exception.Message)"
            }
        }

        # Folder Redirection v One
        if ($this.PolicySettings.FolderRedirection1) {
            $FRPath1 = "\\$($DomainController)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\User\Documents & Settings"
            if ( (Test-Path -Path $FRPath1) -eq $false ) { New-Item -Path $FRPath1 -ItemType Directory  }

            # Replace names with lower-cased-SIDs
            for ($i = 0; $i -lt $this.PolicySettings.FolderRedirection1.Count; $i++) {
                $this.PolicySettings.FolderRedirection1[$i] = $Utils.ReplaceNames($this.PolicySettings.FolderRedirection1[$i],$true)
            }

            try {
                $this.PolicySettings.FolderRedirection1 | Out-File -FilePath $FRPath1\fdeploy1.ini -Encoding unicode
            } catch {
                throw "Failed to save fdeploy1.ini - $($_.Exception.Message)"
            }
        }

        # Scripts
        if ($this.PolicySettings.Scripts) {
            foreach ($Script in $this.PolicySettings.Scripts) {
                $source = $Script.Target
                $ScriptsPath = "\\$($DomainController)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\$source\Scripts"

                if ((Test-Path -Path $ScriptsPath) -eq $false) {
                    try {
                        New-Item -Path $ScriptsPath -Type Directory -Force -ErrorAction Stop
                    } catch {
                        throw "Failed to create $source scripts directory - $($_.Exception.Message)"
                    }

                    # Create psscripts.ini
                    $PSScriptsIniHash = $Utils.ConvertPSCustomObjectToHashTable($Script.PSScriptsIni)
                    $Utils.WriteIniFile("$ScriptsPath\psscripts.ini", $PSScriptsIniHash, "UTF8", $false, $true) # FilePath, InputObject, Encoding, Append, Force 
            
                    # Create scripts.ini
                    $ScriptsIniHash = $Utils.ConvertPSCustomObjectToHashTable($Script.ScriptsIni)
                    $Utils.WriteIniFile("$ScriptsPath\scripts.ini", $ScriptsIniHash, "UTF8", $false, $true) # FilePath, InputObject, Encoding, Append, Force 

                    # Create subfolders and scripts
                    foreach ($ScriptFile in $Script.ScriptFiles) {
                        if ((Test-Path -Path "$ScriptsPath\$($ScriptFile.Type)") -eq $false) {
                            try {
                                New-Item -Path "$ScriptsPath\$($ScriptFile.Type)" -Type Directory -Force -ErrorAction Stop
                            } catch {
                                throw "Failed to create $($ScriptFile.Type) script directory - $($_.Exception.Message)"
                            }

                            try {
                                $ScriptFile.Content | Out-File -FilePath "$ScriptsPath\$($ScriptFile.Type)\$($ScriptFile.Name)" -Encoding default -ErrorAction Stop
                            } catch {
                                throw "Failed to save script $($ScriptFile.FileName) - $($_.Exception.Message)"
                            }
                        }
                    }
                }
            }
        }

        # GPP
        if ($this.PolicySettings.GroupPolicyPreferences) {
            foreach ($GPP in $this.PolicySettings.GroupPolicyPreferences) {
                $GPPRootPath = "\\$($DomainController)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\$($GPP.Target)\Preferences"
                if ( (Test-Path -Path $GPPRootPath) -eq $false ) { New-Item -Path $GPPRootPath -ItemType Directory }

                $GPPPath = "\\$($DomainController)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\$($GPP.Target)\Preferences\$($GPP.Type)"
                if ( (Test-Path -Path $GPPPath) -eq $false ) { New-Item -Path $GPPPath -ItemType Directory }

                $XmlPath = "\\$($DomainController)\SYSVOL\$($Domain)\Policies\$($PolicyGuid)\$($GPP.Target)\Preferences\$($GPP.Type)\$($GPP.XmlFileName)"
                try {
                    for ($i = 0; $i -lt $GPP.XmlContent.Count; $i++) {
                        $GPP.XmlContent[$i] = $Utils.ReplaceNames($GPP.XmlContent[$i],$false)
                    }
                    #foreach ($line in $GPP.XmlContent) {
                    #    $line = $Utils.ReplaceNames($line,$false)
                    #}

                    $GPP.XmlContent | Out-File -FilePath $XmlPath -Encoding utf8 -ErrorAction Stop
                } catch {
                    throw "Failed to write Xml file $($GPP.FileName) - $($_.Exception.Message)"
                }
            }
        }

        # Client Side Extensions
        $gpcObject = $null
        $gpcObject = Get-ADObject -Filter "ObjectClass -eq 'groupPolicyContainer' -and Name -eq '$PolicyGuid'" -Server $DomainController -ErrorAction SilentlyContinue
        # $IncrementBy specifies how much to increment the gpcontainer property 'versionNumber' with
        [uint32]$IncrementBy = 0

        if ($gpcObject) {
            if ($this.gPCMachineExtensionNames) {
                try {
                    #Set-ADObject -Identity $gpcObject.distinguishedName -gPCMachineExtensionNames $this.gPCMachineExtensionNames -Server $DomainController -ErrorAction Stop
                    Set-ADObject -identity $gpcObject.distinguishedname -Replace @{gPCMachineExtensionNames=$this.gPCMachineExtensionNames} -ErrorAction 'Stop' -Server $DomainController
                    # The GPO contains machine settings - add 1 to $IncrementBy (1 is one machine version up)
                    $IncrementBy++
                } catch {
                    throw "Failed to save client side extension for machine - $($_.Exception.Message)"
                }
            }

            if ($this.gPCUserExtensionNames) {
                try {
                    #Set-ADObject -Identity $gpcObject.distinguishedName -gPCUserExtensionNames $this.gPCUserExtensionNames -Server $DomainController -ErrorAction Stop
                    Set-ADObject -identity $gpcObject.distinguishedname -Replace @{gPCUserExtensionNames=$this.gPCUserExtensionNames} -ErrorAction 'Stop' -Server $DomainController
                    # The GPO contains user settings - add 65536 to $IncrementBy (65536 is one user version up)
                    $IncrementBy = $IncrementBy + 65536
                } catch {
                    throw "Failed to save client side extension for user - $($_.Exception.Message)"
                }
            }
            
            # Enable / disable user and computersettings as needed
            # flags:
            # 0 - Enabled
            # 1 - User settings disabled
            # 2 - Computer settings disabled
            # 3 - All settings disabled

            if ($this.ComputerSettingsEnabled -and $this.UserSettingsEnabled) {
                try {
                    Set-ADObject -identity $gpcObject.distinguishedname -Replace @{flags=0} -ErrorAction 'Stop' -Server $DomainController
                } catch {
                    throw "Failed to save flags - $($_.Exception.Message)"
                }
            }
            
            if ($this.ComputerSettingsEnabled -and $this.UserSettingsEnabled -eq $false) {
                try {
                    Set-ADObject -identity $gpcObject.distinguishedname -Replace @{flags=1} -ErrorAction 'Stop' -Server $DomainController
                } catch {
                    throw "Failed to save flags - $($_.Exception.Message)"
                }
            }

            if ($this.ComputerSettingsEnabled -eq $false -and $this.UserSettingsEnabled) {
                try {
                    Set-ADObject -identity $gpcObject.distinguishedname -Replace @{flags=2} -ErrorAction 'Stop' -Server $DomainController
                } catch {
                    throw "Failed to save flags - $($_.Exception.Message)"
                }
            }

            if ($this.ComputerSettingsEnabled -eq $false -and $this.UserSettingsEnabled -eq $false) {
                try {
                    Set-ADObject -identity $gpcObject.distinguishedname -Replace @{flags=3} -ErrorAction 'Stop' -Server $DomainController
                } catch {
                    throw "Failed to save flags - $($_.Exception.Message)"
                }
            }

            # Apply Permissions
            if ($this.Permissions) {
                $acl = Get-Acl "AD:$($gpcObject.distinguishedname)"
                try {
                    $sddl = $Utils.ReplaceNames($this.Permissions,$false)
                    $acl.SetSecurityDescriptorSddlForm($sddl)
                    Set-Acl -Path "AD:$($gpcObject.distinguishedname)" -AclObject $acl
                } catch {
                    throw "Failed to set security descriptor - $($_.Exception.Message)"
                }
            }
        }
        
        # Link the policy to the listed OUs
        if ($DoNotLinkGPO -eq $false) {
            foreach ($LinkTarget in $this.LinkTargets) {
                if ($LinkTarget.LinkPolicy) {
                    try {
                        if ($LinkTarget.LinkEnabled) { $bEnabled = 'Yes' } else { $bEnabled = 'No' }
                        if ($LinkTarget.Enforced) { $bEnforced = 'Yes' } else { $bEnforced = 'No' }
                        $Target = $LinkTarget.Target -ireplace '####defaultNamingContext####', $defaultNamingContext
                        New-GPLink -Name $this.Name -Target $Target -Order $LinkTarget.LinkOrder -LinkEnabled $bEnabled -Enforced $bEnforced -Server $DomainController
                    } catch {
                        throw "Failed to link GPO to $($LinkTarget.Target) - $($_.Exception.Message)"
                    }
                }
            }
        }

        # Apply WMI filter
        if ($this.WMIFilter) {
            $WMIFilterObject = Get-ADObject -Filter "objectClass -eq 'msWMI-Som' -and msWMI-Name -eq '$($this.WMIFilter.Name)'" -ErrorAction SilentlyContinue -Server $DomainController
            if (!$WMIFilterObject) {
                # WMI Filter does not exist. Create it.
                try {
                    $WMIFilterObject = $this.CreateWMIFilter($this.WMIFilter, $DomainController)
                } catch {
                    throw "Failed to create WMI filter - $($_.Exception.Message)"
                }
            }

            if ($WMIFilterObject) {
                $gPCWQLFilter = "[$Domain;$($WMIFilterObject.name);0]" # gPCWQLFilter = [test.local;{9A1CCFB1-235D-4CF5-B349-D9520D38DBF3};0]
                try {
                    Set-ADObject -identity $gpcObject.distinguishedname -Replace @{gPCWQLFilter=$gPCWQLFilter} -ErrorAction 'Stop' -Server $DomainController
                } catch {
                    throw "Failed to assign WMI filter - $($_.Exception.Message)"
                }
            } else {
                Write-Warning "WMI filter '$this.WMIFilter' was not found"
            }
        }

        # Increment policy version number
        try {
            $this.IncrementVersion($GPO.Id, $DomainController, $Domain, $IncrementBy)
        } catch {
            throw "Failed to increment policy version - $($_.Exception.Message)"
        }
    }

    [object] hidden CreateWMIFilter (
        [WMIFilter]$Filter,
        [string]$DomainController
    ) {
        $Domain = [Domain]::GetCurrentDomain()
        $DomainDN = $Domain.GetDirectoryEntry() | Select-Object -ExpandProperty DistinguishedName
        $guid = ("{" + (New-Guid).Guid + "}").ToUpper()
        $Path = "CN=SOM,CN=WMIPolicy,CN=System,$DomainDN"
        $distinguishedName = "CN=$guid,$Path"
        
        $now = (Get-Date).ToUniversalTime()
        $year = ($now.Year).ToString("0000")
        $month = ($now.month).ToString("00")
        $day = ($now.day).ToString("00")
        $hour = ($now.hour).ToString("00")
        $minute = ($now.minute).ToString("00")
        $second = ($now.second).ToString("00")
        $millisecond = ($now.millisecond * 1000).ToString("000000")
        $CreationDate = "$year$month$day$hour$minute$second.$millisecond-000" #20191023212335.425000-000
        
        $OtherAttribs = @{
            cn = $guid
            distinguishedName = $distinguishedName
            instanceType = 4
            showInAdvancedViewOnly = 'TRUE'
            'msWMI-Name' = $Filter.Name
            'msWMI-Parm2' = $Filter.Query
            'msWMI-Author' = 'robert@test.local'
            'msWMI-ID' = $guid
            'msWMI-ChangeDate' = $CreationDate
            'msWMI-CreationDate' = $CreationDate
        }

        if ($Filter.Description) { $OtherAttribs.Add('msWMI-Parm1', $Filter.Description) }
        
        try {
            $result = New-ADObject -Name $guid -Type 'msWMI-Som' -Path $Path -OtherAttributes $OtherAttribs -PassThru -Server $DomainController
        } catch {
            throw $_
        }
        
        return $result
    }

    [void]RemoveGroupPolicyFromAD(
        [string]$DomainController
    ) {
        try {
            $GPO = Get-GPO -Name $this.Name -Server $DomainController -ErrorAction 'Ignore' 
            if ($GPO) {
                $GPO | Remove-GPO -Server $DomainController -ErrorAction 'Stop'
            }
        } 
        catch {
            throw $_
        }
    }
}

class Utils : BaseSettings {
    Utils () {
        $this.ObjectType = "Utils"
    }

    [PSCustomObject]GetIniFile (
        [string[]]$FilePath
    ) {
        $ini = @{}
        $file = Get-ChildItem -path $FilePath -Force
        if(!(Test-Path $File.FullName)) {
            throw "$($File.FullName) - File not found"
        }
        
        $CommentCount = $null
        $NameValue = $null
        $Section = $null
        switch -regex -file $filepath {
            "^\[(.+)\]" { # section
                $section = $Matches[1]
                $ini[$section] = @{}
                $CommentCount = 0
            }
            
            "^(;.*)$" { # comment
                $Value = $Matches[1]
                $CommentCount = $CommentCount + 1
                $NameValue = "Comment" + $CommentCount
                $Ini[$Section][$NameValue] = $Value
            }

            "(.+?)\s*=(.*)" { # key
                $NameValue,$Value = $Matches[1..2]
                if ($value.Gettype().name -eq "String") {
                    $Value = $value.Trim()
                }
                
                if ($Value -eq "true") {
                    $Value = $true
                } elseif ($Value -eq "false") {
                    $Value = $false
                }
                
                $ini[$Section][$NameValue] = $Value
            }
        }
        
        return $ini
    }

    [PSCustomObject]GetSecurityTemplateContent (
        [string[]]$Content
    ) {
        $ini = @{}

        $CommentCount = $null
        $ValueCount = $null
        $NameValue = $null
        $Section = $null
        switch -regex ($Content) {
            "^\[(.+)\]" { # section
                $section = $Matches[1]
                $ini[$section] = @{}
                $CommentCount = 0
                $ValueCount = 0
            }
            
            "^(;.*)$" { # comment
                $Value = $Matches[1]
                $CommentCount = $CommentCount + 1
                $NameValue = "Comment" + $CommentCount
                $Ini[$Section][$NameValue] = $Value
            }

            #"^((?!\[).)*$" { # key
            "^((?!\[(.+)\]).)*$" { # key
                $Value = $Matches[0]
                $ValueCount++
                $NameValue = "Value" + $ValueCount
                $ini[$Section][$NameValue] = $Value
            }
        }
        
        return $ini
    }

    [void]WriteIniFile (
	    [string]$FilePath,
	    [Hashtable]$InputObject, 
	    [string]$Encoding, 
        [bool]$Append, 
        [bool]$Force 
    ) {
        $FileEncoding = $null
        
        switch ($Encoding) {
            "Unicode" { $FileEncoding = New-Object System.Text.UnicodeEncoding }
            "UTF7" { $FileEncoding = New-Object System.Text.UTF7Encoding }
            "UTF8" { $FileEncoding = New-Object System.Text.UTF8Encoding }
            "UTF8NoBOM" { $FileEncoding = New-Object System.Text.UTF8Encoding($false) }
            "UTF32" { $FileEncoding = New-Object System.Text.UTF32Encoding }
            "ASCII" { $FileEncoding = New-Object System.Text.ASCIIEncoding }
            "BigEndianUnicode" { $FileEncoding = New-Object [System.Text.Encoding]::BigEndianUnicode }
            "Default" { $FileEncoding = New-Object [System.Text.Encoding]::Default  }
            "OEM" { $FileEncoding = New-Object [System.Text.Encoding]::OEM }
        }
        
        if ($append) {
            $OutFile = Get-Item $FilePath
        } else {
            $OutFile = New-Item -ItemType file -Path $Filepath -Force:$Force
        } 
        
        foreach ($i in $InputObject.keys) {
            if (!($($InputObject[$i].GetType().Name) -eq "Hashtable")) {
                #No Sections 
                $Errorcount = 0
                do {
                    try {
                        $Lineout = "$i=$($InputObject[$i])" + "`r`n"
                        [System.IO.File]::AppendAllText($OutFile,$LineOut,$FileEncoding)
                        $Errorcount = 100
                    } catch {
                        Start-Sleep -Milliseconds 500
                        $Errorcount++
                    }
                } while ($Errorcount -lt 10)
                
            } else {
                #Sections 
                $Errorcount = 0
                do {
                    try {
                        $Lineout = "[$i]" + "`r`n"
                        [System.IO.File]::AppendAllText($OutFile,$LineOut,$FileEncoding)
                        $Errorcount = 100
                    } catch {
                        Start-Sleep -Milliseconds 500
                        $Errorcount++
                    }
                } while ($Errorcount -lt 10)
                
                foreach ($j in $($InputObject[$i].keys | Sort-Object)) {
                    if ($j -match "^Comment[\d]+") {
                        $Errorcount = 0
                        do {
                            try {
                                $Lineout = "$($InputObject[$i][$j])" + "`r`n"
                                [System.IO.File]::AppendAllText($OutFile,$LineOut,$FileEncoding)
                                $Errorcount = 100
                            } catch {
                                Start-Sleep -Milliseconds 500
                                $Errorcount++
                            }
                        } 
                        while ($Errorcount -lt 10)
                    } else {
                        $Errorcount = 0
                        do {
                            try {
                                $Lineout = "$j=$($InputObject[$i][$j])" + "`r`n"
                                [System.IO.File]::AppendAllText($OutFile,$LineOut,$FileEncoding)
                                $Errorcount = 100
                            } catch {
                                Start-Sleep -Milliseconds 500
                                $Errorcount++
                            }
                        } while ($Errorcount -lt 10)
                    }   
                } 
                
                do {
                    try {
                        $Lineout =  "`r`n"
                        [System.IO.File]::AppendAllText($OutFile,$LineOut,$FileEncoding)
                        $Errorcount = 100
                    } catch {
                        Start-Sleep -Milliseconds 500
                        $Errorcount++
                    }
                } while ($Errorcount -lt 10)
            } 
        } 
    }

    [string]ReplaceSIDs (
        [string]$InputString
    ) {
        $reg = [regex]::new('[S|s]-\d-(?:\d+-){1,14}\d+')
        $hits = $reg.Matches($InputString)
        if ($hits.Value.Count -gt 0) {
            $Values = @($hits.Value.Split(','))
            foreach ($value in $Values) {
                if ($value.Length -gt 12) { # Only convert if SID is longer than 12 characters. All 12 character or less SIDs are well known.
                    # Convert SID into name
                    $objSID = New-Object System.Security.Principal.SecurityIdentifier($value)
                    try {
                        # Added back the 'Domain'-part to security principals, so NT AUTHORITY, NT SERVICE etc can be resolved. 
                        $ActualDomain,$ActualName = ($objSID.Translate( [System.Security.Principal.NTAccount] )).Value.Split('\') 
                        # If ActualDomain is the the domain name, replace with 'DOMAIN'
                        if ( ($ActualDomain -eq (Get-ADDomain).DnsRoot) -or ($ActualDomain -eq (Get-ADDomain).NetBIOSName) ){
                            # ActualDomain is the DomainFQDN or DomainNB - replace with 'DOMAIN'
                            $ActualDomain = 'DOMAIN'
                        }
                        $InputString = $InputString.Replace($value, "####Replace[$ActualDomain\$ActualName]")
                    } catch {
                        # Do nothing. Was unable to translate SID into name. It probably means it is a well
                        # known SID. In which case, we don't want it to be translated.
                    }
                }
            }
        }
        
        return $InputString
    }

    # The $LowerCase switch is used by policies that require a lower case SID, i.e. s-1-5... as opposed to S-1-5....
    # The folder redirection file fdeploy1.ini always uses lower-case SIDs. 
    [string]ReplaceNames (
        [string]$InputString,
        [switch]$LowerCase
    ) {
        if ($InputString -imatch '####Replace') {
            $reg = [regex]::new('####Replace\[(.*?)\]')
            $hits = $reg.Matches($InputString)
            if ($hits.Value.Count -gt 0) {
                $Values = @(($hits.Value.Replace('####Replace','')).Split(','))
                foreach ($value in $Values) {
                    $domain,$usr = ($value.Replace('[', '').Replace(']', '')).split('\')
                    if ($domain -eq 'DOMAIN') {
                        $domain = (Get-ADDomain).NetBIOSName #.Name is incorrect if .Name -ne .NetBIOSName. Can be either .NetBIOSName or .DnsRoot (Domain FQDN)
                    }
                
                    try {
                        $objUser = New-Object System.Security.Principal.NTAccount("$domain", "$usr")
                        $objSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
                        
                        if ($objSID) {
                            $SID = $objSID.Value
                            if ($LowerCase) {
                                $SID = $SID.ToLower()
                            }
                            $InputString = $InputString.Replace($value, $SID)
                        } else {
                            # Did not find name in AD.
                            Write-Warning "Did not find '$domain\$usr'. Group policy import will fail if not fixed." -WarningAction Continue
                        }
                    } catch {
                        Write-Warning "Failed to resolve SID for: $domain\$usr" -WarningAction Continue
                        throw $_
                    }
                }
            }
        }
        
        $InputString = $InputString.Replace('####Replace', '')
        return $InputString
    }

    [Object]ConvertPSCustomObjectToHashTable(
        [Object]$PSCustomObject
    ) {
        $Utils = [Utils]::new()
        if ($null -eq $PSCustomObject) { return $null }

        if ($PSCustomObject -is [System.Collections.IEnumerable] -and $PSCustomObject -isnot [string]) {
            $collection = @()
            foreach ($object in $PSCustomObject) { $collection += $Utils.ConvertPSCustomObjectToHashTable($object) }
        } elseif ($PSCustomObject -is [psobject]) {
            $hash = @{}

            foreach ($property in $PSCustomObject.PSObject.Properties) {
                $hash.Add($property.Name, $Utils.ConvertPSCustomObjectToHashTable($property.Value))
            }

            return $hash
        } else { 
            return $PSCustomObject
        }

        return $null
    }

    [Object]ConvertPSCustomObjectToOrderedHashTable(
        [Object]$PSCustomObject
    ) {
        $Utils = [Utils]::new()
        if ($null -eq $PSCustomObject) { return $null }

        if ($PSCustomObject -is [System.Collections.IEnumerable] -and $PSCustomObject -isnot [string]) {
            $collection = @()
            foreach ($object in $PSCustomObject) { $collection += $Utils.ConvertPSCustomObjectToHashTable($object) }
        } elseif ($PSCustomObject -is [psobject]) {
            $hash = [ordered]@{}

            foreach ($property in $PSCustomObject.PSObject.Properties) {
                $hash.Add($property.Name, $Utils.ConvertPSCustomObjectToHashTable($property.Value))
            }

            return $hash
        } else { 
            return $PSCustomObject
        }

        return $null
    }

    [string[]]FormatXml (
        [xml]$Xml,
        [int]$Indent
    ) {
        $StringWriter = New-Object System.IO.StringWriter 
        $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter 
        $xmlWriter.Formatting = "indented" 
        $xmlWriter.Indentation = $Indent
        
        $xml.WriteContentTo($XmlWriter) 
        $XmlWriter.Flush();$StringWriter.Flush() 
        
        $arrFormatedXml = $StringWriter.ToString().Split("`r`n", [System.StringSplitOptions]::RemoveEmptyEntries)
        return $arrFormatedXml
    }

    [xml]ReplaceXmlValues (
        [xml]$XmlContent,
        [bool]$IsComparing
    ) {
        if ($IsComparing) {
            # These values need to be the same when camparing. Otherwise, the policy will always show as different.
            $ChangedDate = "2020-11-05 12:00:00"
            $newGuid = "E6FBCC5A-59D0-43CC-AD14-FD1143A4ACD8"
        } else {
            $ChangedDate = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
            $newGuid = (New-Guid).ToString().ToUpper()
        }

        # Replace uid
        $nodes = @($XmlContent.SelectNodes("*/*[@uid]"))
        foreach ($node in $nodes) {
            $node.uid = $newGuid
        }
        # Replace changed
        $nodes = @($XmlContent.SelectNodes("*/*[@changed]"))
        foreach ($node in $nodes) {
            $node.changed = $ChangedDate
        }

        # Replace Author
        $nodes = @($XmlContent.SelectNodes(".//Author"))
        foreach ($node in $nodes) {
            $node.'#text' = $env:USERNAME
        }

        return $XmlContent
    }

    [Object]GetScriptPolicyConfig(
        [Object]$Policy,
        [string]$ScriptType,
        [bool]$PowerShell,
        [string]$Scope # Machine, User
    ) {
        $Utils = [Utils]::new()
        $ScriptsToreturn = @()

        $ScriptCmd = [System.String]::Empty
        $Target = $null
        switch ($ScriptType) {
            Startup {
                switch ($PowerShell) {
                    $false {  
                        $Target = $Policy.PolicySettings.Scripts | Where-Object { $_.Target -eq $Scope }
                        $ScriptCmd = $Target.ScriptsIni.Startup
                    }
                    $true {  
                        $Target = $Policy.PolicySettings.Scripts | Where-Object { $_.Target -eq $Scope }
                        $ScriptCmd = $Target.PSScriptsIni.Startup
                    }
                }
            }
            Shutdown {  
                switch ($PowerShell) {
                    $false {  
                        $Target = $Policy.PolicySettings.Scripts | Where-Object { $_.Target -eq $Scope }
                        $ScriptCmd = $Target.ScriptsIni.Shutdown
                    }
                    $true {  
                        $Target = $Policy.PolicySettings.Scripts | Where-Object { $_.Target -eq $Scope }
                        $ScriptCmd = $Target.PSScriptsIni.Shutdown
                    }
                }
            }
            Logon {  
                switch ($PowerShell) {
                    $false {  
                        $Target = $Policy.PolicySettings.Scripts | Where-Object { $_.Target -eq $Scope }
                        $ScriptCmd = $Target.ScriptsIni.Logon
                    }
                    $true {  
                        $Target = $Policy.PolicySettings.Scripts | Where-Object { $_.Target -eq $Scope }
                        $ScriptCmd = $Target.PSScriptsIni.Logon
                    }
                }
            }
            Logoff {  
                switch ($PowerShell) {
                    $false {  
                        $Target = $Policy.PolicySettings.Scripts | Where-Object { $_.Target -eq $Scope }
                        $ScriptCmd = $Target.ScriptsIni.Logoff
                    }
                    $true {  
                        $Target = $Policy.PolicySettings.Scripts | Where-Object { $_.Target -eq $Scope }
                        $ScriptCmd = $Target.PSScriptsIni.Logoff
                    }
                }
            }
        }

        # Get all scripts
        $allScripts = $Utils.ConvertPSCustomObjectToOrderedHashTable($ScriptCmd)
        $cmd = [string]::Empty;
        
        $param = [string]::Empty;
        foreach ($item in $allScripts.Keys) {
            if ($item -imatch 'CmdLine') { $cmd = $allScripts[$item] }
            if ($item -imatch 'Parameters') { 
                $param = $allScripts[$item] 

                # Get script content
                $ScriptContent = ($Target.ScriptFiles | Where-Object { $_.Name -eq $cmd }).Content -join "`r`n"

                $ScriptComparer = [ScriptComparer]::new()
                $ScriptComparer.ScriptType = $ScriptType
                $ScriptComparer.ScriptName = $cmd
                $ScriptComparer.ScriptParameters = $param
                $ScriptComparer.IsPowerShell = $PowerShell
                $ScriptComparer.Content = $ScriptContent
                $ScriptsToreturn += $ScriptComparer
            }
        }
        return $ScriptsToReturn
    }

    # The GPO.cmt comment file must contain no more than 2047 carachters, where every new line counts 2 (\r\n)
    [bool]CommentInSpec (
        [array]$InputObject
    ) {
        [int]$threshold = 2047
        [int]$count = 0
        $InputObject.foreach({
            $count += $_.Length
            $count = $count + 2
        })
        $count = $count - 2
        if ($count -gt $threshold) {
            return $false
        }
        else  {
            return $true
        }  
    }
}

class IniSection {
    [string]$SectionName
    [string[]]$SectionContent

    IniSection () { }
}

class Linktarget : BaseSettings {
    [string]$Target
    [int]$LinkOrder
    [bool]$LinkPolicy
    [bool]$LinkEnabled
    [bool]$Enforced

    LinkTarget () {
        $this.LinkPolicy = $false
        $this.LinkEnabled = $false
        $this.Enforced = $false
        $this.ObjectType = "LinkTarget"
    }
    
    LinkTarget (
        [string]$Target,
        [int]$LinkOrder,
        [bool]$LinkPolicy,
        [bool]$LinkEnabled,
        [bool]$Enforced
    ) {
        $this.Target = $Target
        $this.LinkOrder = $Linkorder
        $this.LinkPolicy = $LinkPolicy
        $this.LinkEnabled = $LinkEnabled
        $this.Enforced = $Enforced
        $this.ObjectType = "LinkTarget"
    }
}

class PolicySettings : BaseSettings {
    [RegistrySetting[]]$RegistrySettings
    [AuditSetting[]]$AuditSettings
    [string[]]$SecurityTemplate
    [string[]]$FolderRedirection
    [string[]]$FolderRedirection1
    [string[]]$GPOComments
    [string[]]$MachineComments
    [string[]]$UserComments
    [Script[]]$Scripts
    [GroupPolicyPreference[]]$GroupPolicyPreferences
    
    PolicySettings () {
        $this.ObjectType = "PolicySettings"
    }

    Add (
        [RegistrySetting]$RegistrySetting
    ) {
        $this.RegistrySettings += $RegistrySetting
    }

    Add (
        [AuditSetting]$AuditSetting
    ) {
        $this.AuditSettings += $AuditSetting
    }
}

class WMIFilter : BaseSettings {
    [string]$Name
    [string]$Query
    [string]$Description

    WMIFilter () {
        $this.ObjectType = "WMIFilter"
    }

    WMIFilter (
        [string]$Name,
        [string]$Query,
        [string]$Description
    ) {
        $this.ObjectType = "WMIFilter"
        $this.Name = $Name
        $this.Query = $Query
        $this.Description = $Description
    }
}

class Permission : BaseSettings {
    [string]$Trustee
    [string]$TrusteeType
    [string]$PermissionLevel
    [bool]$Inherited
    [bool]$Replace

    Permission () {
        $this.ObjectType = "Permission"
        $this.Replace = $true
    }

    Permission (
        [string]$Trustee,
        [string]$TrusteeType,
        [string]$PermissionLevel,
        [bool]$Inherited
    ) {
        $this.ObjectType = "Permission"
        $this.Trustee = $Trustee
        $this.TrusteeType = $TrusteeType
        $this.PermissionLevel = $PermissionLevel
        $this.Inherited = $Inherited
        $this.Replace = $true
    }
}

class RegistrySetting : BaseSettings {
    [string]$Target # User, Machine
    [string]$KeyName
    [ValidateSet("REG_SZ","REG_DWORD","REG_QWORD","REG_NONE","REG_MULTI_SZ","REG_BINARY","REG_EXPAND_SZ","REG_DWORD_LITTLE_ENDIAN","REG_DWORD_BIG_ENDIAN","REG_QWORD_LITTLE_ENDIAN")]
    [string]$ValueType
    [string]$ValueName
    [string]$ValueData

    RegistrySetting () {
        $this.ObjectType = "RegistrySetting"
    }

    RegistrySetting (
        [string]$Target,
        [string]$KeyName,
        [string]$ValueType,
        [string]$ValueName,
        [string]$ValueData
    ) {
        $this.ObjectType = "RegistrySetting"
        $this.Target = $Target
        $this.KeyName = $KeyName
        $this.ValueType = $ValueType
        $this.ValueName = $ValueName
        $this.ValueData = $ValueData
        
        # Need to verify if value contains a SID other than well known SIDs
        #$Utils = [Utils]::new()
        #$this.ValueData = $Utils.ReplaceSIDs($ValueData) 
    }
}

class AuditSetting : BaseSettings {
    [string]${Machine Name}
    [string]${Policy Target}
    [string]$SubCategory
    [string]${SubCategory GUID}
    [string]${Inclusion Setting}
    [string]${Exclusion Setting}
    [string]${Setting Value}

    AuditSetting() {
        $this.ObjectType = "AuditSetting"
    }

    AuditSetting(
        # Machine Name,Policy Target,Subcategory,Subcategory GUID,Inclusion Setting,Exclusion Setting,Setting Value
        [string]${Machine Name},
        [string]${Policy Target},
        [string]$SubCategory,
        [string]${SubCategory GUID},
        [string]${Inclusion Setting},
        [string]${Exclusion Setting},
        [string]${Setting Value}
    ) {
        $this.{Machine Name} = ${Machine Name}
        $this.{Policy Target} = ${Policy Target}
        $this.SubCategory = $SubCategory
        $this.{SubCategory GUID} = ${SubCategory GUID}
        $this.{Exclusion Setting} = ${Exclusion Setting}
        $this.{Inclusion Setting} = ${Inclusion Setting}
        $this.{Setting Value} = ${Setting Value}
        $this.ObjectType = "AuditSetting"
    }
}

class SecurityTemplate : BaseSettings {
    [IniSection[]]$GplTemplInf

    SecurityTemplate () {
        $this.ObjectType = "SecurityTemplate"
    }
}

class ScriptFile : BaseSettings {
    [string]$Type  # Logon, Logoff, Startup or Shutdown
    [string]$Name
    [string[]]$Content

    ScriptFile () {}
}

class Script : BaseSettings {
    [string]$Target # User or Machine
    [PSCustomObject]$ScriptsIni
    [PSCustomObject]$PSScriptsIni
    [ScriptFile[]]$ScriptFiles

    Script () {
        $this.ObjectType = "Scripts"
    }
}

class ScriptComparer : BaseSettings {
    [string]$ScriptType
    [string]$ScriptName
    [string]$ScriptParameters
    [string]$IsPowerShell
    [string]$Content

    ScriptComparer () {
        $this.ObjectType = "ScriptComparer"
    }
}

class GroupPolicyPreference : BaseSettings {
    [string]$Target
    [string]$Type
    [string]$XmlFileName
    [string[]]$XmlContent

    GroupPolicyPreference () {
        $this.ObjectType = "GroupPolicyPreference"
    }
}

function Export-GroupPolicyFromAD {
    param (
        [string]$Name,
        [string]$FileName,
        [switch]$IncludeLinks
    )

    $GPO = [GroupPolicy]::new()
    try {
        $GPO.GetPolicyFromAD($Name, $IncludeLinks)
    } catch {
        throw "Failed to get policy from AD - $($_.Exception.Message)"
    }
    
    try {
        $GPO.WritePolicyToJson($Filename)
    } catch {
        throw "Failed to write policy to file - $($_.Exception.Message)"
    }
}

function Test-GroupPolicyExistenceInAD {
    [OutputType([Bool])]
    param (
        [string]$Name,
        [string]$DomainController = $([DomainController]::findone($($(New-Object DirectoryContext("domain",$([Domain]::GetComputerDomain().Name)))),$([ActiveDirectorySite]::GetComputerSite()).Name).Name)
    )
    try {
        Get-GPO -Name $Name -Server $DomainController -ErrorAction 'Stop' | 
        Out-Null
        $true
    } 
    catch {
        $false
    }
}

function Import-GroupPolicyToAD {
    param (
        [string]$Name,
        [string]$FileName,
        [hashtable]$Replacements,
        [switch]$PerformBackup,
        [switch]$OverwriteExistingPolicy,
        [switch]$RemoveLinks,
        [switch]$DoNotLinkGPO,
        [switch]$DefaultPermissions,
        [string]$DomainController = $([DomainController]::findone($($(New-Object DirectoryContext("domain",$([Domain]::GetComputerDomain().Name)))),$([ActiveDirectorySite]::GetComputerSite()).Name).Name)
    )

    $GPO = [GroupPolicy]::new()
    
    try {
        $GPO.GetPolicyFromJson($FileName,$Replacements, $false)
    } catch {
        throw "Failed to read policy from file - $($_.Exception.Message)"
    }

    if ($Name) {
        $GPO.Name = $Name
    }

    if ($DefaultPermissions) {
        $GPO.Permissions=$Null
    }

    try {
        $GPO.WritePolicyToAD($OverwriteExistingPolicy, $PerformBackup, $RemoveLinks, $DoNotLinkGPO, $DomainController)
    } catch {
        # If the GPO import failed, a GPO with no, or only some, settings
        # may have been created - ensure that any incomplete GPO is removed
        $GPO.RemoveGroupPolicyFromAD($DomainController)
        throw "Failed to write policy to AD - $($_.Exception.Message)"
    }
}

Export-ModuleMember -function Export-GroupPolicyFromAD,Import-GroupPolicyToAD,Compare-GroupPolicyObjects,Test-GroupPolicyExistenceInAD