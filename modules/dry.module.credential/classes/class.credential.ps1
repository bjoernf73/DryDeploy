using Namespace System.Collections
<#
 This module handles credentials for DryDeploy

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.credential/main/LICENSE
 
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License along
 with this program; if not, write to the Free Software Foundation, Inc.,
 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#>

class Credentials {
    [ArrayList] $Credentials
    [String]    $Path
    [DateTime]  $Accessed

    Credentials ([String] $Path) {
        try {
            if (-not (Test-Path -Path $Path -ErrorAction Ignore)) {
                throw "The credentials file $Path does not exist"
            }
            $This.Path          = $Path
            $This.Credentials   = $This.ReadFromFile()
            $This.Accessed      = Get-Date
        }
        catch {
            throw $_
        }
    }

    [ArrayList] ReadFromFile() {
        try {
            return [ArrayList] $(Get-Content -Path $This.Path -ErrorAction Stop | 
            ConvertFrom-Json -ErrorAction Stop).Credentials
        }
        catch {
            throw $_
        }
    }

    [Void] WriteToFile() {
        try {
            $SetContentParams   = @{
                Path            = $This.Path 
                Value           = (ConvertTo-Json -InputObject $This -Depth 20) 
                Force           = $True 
                ErrorAction     = 'Stop'
            }
            Set-Content @SetContentParams
        }
        catch {
            throw $_
        }
    }

    [Void] AddCredential(
        [String]$Alias,
        [String]$EnvConfig,
        [String]$Type,
        [PSCredential] $Credential) {
        try {
            $CredObj            = [PSCustomObject]@{
                Alias           = $Alias
                EnvConfig    = $EnvConfig
                Type            = $Type
                UserName        = $Credential.UserName
                encryptedstring = $Credential.Password | ConvertFrom-SecureString -ErrorAction Stop
            }
    
            if ($This.TestCredential($Alias,$EnvConfig)) {
                ol w "Credential '$Alias' in '$EnvConfig' exists already - removing, and adding the new instance"
            }
            $This.Credentials = @($This.Credentials | 
            Where-Object { 
                (-not (($_.Alias -eq $Alias) -and ($_.EnvConfig -eq $EnvConfig)))
            })
            $This.Credentials += @($CredObj)
            $This.WriteToFile()
        }
        catch {
            throw $_
        }
    }

    [Void] AddCredential(
        [String]$Alias,
        [String]$EnvConfig,
        [String]$Type,
        [String]$UserName, 
        [String]$pw) {
        try {
            [SecureString]$SecStringPassword = ConvertTo-SecureString $pw -AsPlainText -Force
            [PSCredential]$Credential        = New-Object System.Management.Automation.PSCredential ($UserName, $SecStringPassword)
            
            $CredObj            = [PSCustomObject]@{
                Alias           = $Alias
                EnvConfig    = $EnvConfig
                Type            = $Type
                UserName        = $Credential.UserName
                encryptedstring = $Credential.Password | ConvertFrom-SecureString -ErrorAction Stop
            }

            if ($This.TestCredential($Alias,$EnvConfig)) {
                ol w "The Credential '$Alias' exists already - removing it, and adding the new instance"
            }
            $This.Credentials = @($This.Credentials | 
            Where-Object { 
                (-not (($_.Alias -eq $Alias) -and ($_.EnvConfig -eq $EnvConfig)))
            })
            $This.Credentials += @($CredObj)
            $This.WriteToFile()
        }
        catch {
            throw $_
        }
    }

    [Void] AddCredentialPlaceholder(
        [String]$Alias, 
        [String]$EnvConfig, 
        [String]$Type,
        [String]$UserName) {
        try {
            if (-not ($This.TestCredential($Alias,$EnvConfig))) {
                ol v "The Alias '$Alias' in '$EnvConfig' not found, adding it."
                $CredObj            = [PSCustomObject]@{
                    Alias           = $Alias
                    EnvConfig    = $EnvConfig
                    Type            = $Type
                    UserName            = $UserName
                }
                $This.Credentials += @($CredObj)
                $This.WriteToFile()
            }
        }
        catch {
            throw $_
        } 
    }

    [Void] AddCredentialPlaceholder(
        [String]$Alias, 
        [String]$EnvConfig, 
        [String]$Type) {
        try {
            if (-not ($This.TestCredential($Alias,$EnvConfig))) {
                ol v "The Alias '$Alias' in '$EnvConfig' not found, adding it."
                $CredObj            = [PSCustomObject]@{
                    Alias           = $Alias
                    EnvConfig    = $EnvConfig
                    Type            = $Type
                }
                $This.Credentials += @($CredObj)
                $This.WriteToFile()
            }
        }
        catch {
            throw $_
        } 
    }

    [PSCredential] PromptForCredential(
        [String]$Alias,
        [String]$EnvConfig,
        [String]$Type) {
        try {
            [PSCredential]$PromptCredential = Get-Credential -Message "Credential '$Alias' in '$EnvConfig'"
            $This.AddCredential($Alias,$EnvConfig,$Type,$PromptCredential)
            return $PromptCredential
        }
        catch {
            throw $_
        }
    }

    [PSCredential] PromptForCredential(
        [String]$Alias,
        [String]$EnvConfig,
        [String]$Type,
        [String]$UserName) {
        try {
            [PSCredential]$PromptCredential = Get-Credential -Message "Credential '$Alias' in '$EnvConfig'" -UserName $UserName
            $This.AddCredential($Alias,$EnvConfig,$Type,$PromptCredential)
            return $PromptCredential
        }
        catch {
            throw $_
        }
    }

    [PSCredential] GetCredential( 
        [String]$Alias,
        [String]$EnvConfig) {
        try {
            if ($This.TestCredential($Alias,$EnvConfig)) {
                $CredentialMatch = $This.GetCredentialMatch($Alias,$EnvConfig)

                #! this returns 'not all code paths return value within method'...
                <#
                 switch ($CredentialMatch.Type) {
                    'hashicorpvault' {
                        return [PSCredential]($This.GetCredentialFromHashicorpVault($Alias,$EnvConfig))
                    }
                    'ansiblevault' {
                        return [PSCredential]($This.GetCredentialFromAnsibleVault($Alias,$EnvConfig))
                    }
                    default {
                        return [PSCredential]($This.GetCredentialFromEncryptedSecureString($Alias,$EnvConfig))
                    }
                }
                
                #>
                if ($CredentialMatch.Type -eq 'hashicorpvault') {
                    return [PSCredential]($This.GetCredentialFromHashicorpVault($Alias,$EnvConfig,$CredentialMatch))
                }
                elseif ($CredentialMatch.Type -eq 'ansiblevault') {
                    return [PSCredential]($This.GetCredentialFromAnsibleVault($Alias,$EnvConfig,$CredentialMatch))
                }
                elseif ($CredentialMatch.Type -eq 'encryptedstring') {
                    return [PSCredential]($This.GetCredentialFromEncryptedSecureString($Alias,$EnvConfig,$CredentialMatch))
                }
                else {
                    # defaulting to encryptedsecurestring
                    ol w "Unable to determine the Credential Type - defaulting to 'encryptedstring'"
                    return [PSCredential]($This.GetCredentialFromEncryptedSecureString($Alias,$EnvConfig,$CredentialMatch))
                }       
            }
            else {
                if ($GLOBAL:dry_var_global_SuppressInteractivePrompts) {
                    throw "Found no credential '$Alias' in '$EnvConfig'"
                }
                else {
                    ol w "You may suppress interactive prompts with the -SuppressInteractivePrompts switch"
                    return [PSCredential]($This.PromptForCredential($Alias,$EnvConfig,$GLOBAL:dry_var_global_Configuration.CredentialsType))
                }
            }
        }
        catch {
            throw $_
        }
    }

    [PSCredential] GetCredentialFromEncryptedSecureString(
        [String] $Alias,
        [String] $EnvConfig,
        [PSCustomObject] $CredObject) {
        try {
            try {
                if (($null -eq $CredObject.encryptedstring) -or (($CredObject.encryptedstring).Trim() -eq '')) {
                    if (($null -ne $CredObject.UserName) -and ($CredObject.UserName.Trim() -ne '')) {
                        [PSCredential]$Credential = ($This.PromptForCredential($Alias,$EnvConfig,$GLOBAL:dry_var_global_Configuration.CredentialsType,$CredObject.UserName))
                    }
                    else {
                        [PSCredential]$Credential = ($This.PromptForCredential($Alias,$EnvConfig,$GLOBAL:dry_var_global_Configuration.CredentialsType))
                    }
                    
                }
                else {
                    $SecureString = ConvertTo-SecureString -String $CredObject.encryptedstring -ErrorAction 'Stop'
                    [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($CredObject.UserName, $SecureString)
                }
                
                if ($GLOBAL:dry_var_global_ShowPasswords) {
                    ol w @("Credential: $Alias ($EnvConfig)","$($CredObject.UserName) ==> $($Credential.GetNetworkCredential().Password)")
                }
                else {
                    ol i @("Credential: $Alias ($EnvConfig)","$($CredObject.UserName)")
                }
                return $Credential
            }
            catch [System.Security.Cryptography.CryptographicException] {
                if ($GLOBAL:dry_var_global_SuppressInteractivePrompts) {
                    throw "CryptographicException: Credential '$Alias' in '$EnvConfig' could not be decrypted - probably not created on this system"
                }
                else {
                    ol w "CryptographicException: Credential '$Alias' in '$EnvConfig' was probably not created on this system - prompting for correct credential. You may suppress with -SuppressInteractivePrompts"
                    if (($null -ne $CredObject.UserName) -and ($CredObject.UserName.Trim() -ne '')) {
                        [PSCredential]$Credential = ($This.PromptForCredential($Alias,$EnvConfig,$GLOBAL:dry_var_global_Configuration.CredentialsType,$CredObject.UserName))
                    }
                    else {
                        [PSCredential]$Credential = ($This.PromptForCredential($Alias,$EnvConfig,$GLOBAL:dry_var_global_Configuration.CredentialsType))
                    }
                    if ($GLOBAL:dry_var_global_ShowPasswords) {
                        ol w @("Credential: $Alias ($EnvConfig)","$($CredObject.UserName) ==> $($Credential.GetNetworkCredential().Password)")
                    }
                    else {
                        ol i @("Credential: $Alias ($EnvConfig)","$($CredObject.UserName)")
                    }
                    return $Credential
                }
            }
            catch { 
                throw $_
            }
        }
        catch {
            <#   
                $PSCmdLet.ThrowTerminatingError($_) in classes generates the 'Not 
                all code paths returns value within method' in classes other than 
                'void' - using 'throw $_' instead 
            #>
            throw $_
        }
    }

    [PSCredential] GetCredentialFromHashicorpVault(
        [String] $Alias,
        [String] $EnvConfig,
        [PSCustomObject] $CredObject) {
        #! just a placeholder - not implemented
        try {
            try {
                if (($CredObject.encryptedstring).Trim() -eq '') {
                    throw "Empty encryptedstring for '$Alias' in '$EnvConfig'"
                }
                $SecureString = ConvertTo-SecureString -String $CredObject.encryptedstring -ErrorAction 'Stop'
                [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($CredObject.UserName, $SecureString)
                
                if ($GLOBAL:dry_var_global_ShowPasswords) {
                    ol w @("Credential: $Alias ($EnvConfig)","$($CredObject.UserName) ==> $($Credential.GetNetworkCredential().Password)")
                }
                else {
                    ol i @("Credential: $Alias ($EnvConfig)","$($CredObject.UserName)")
                }
                return $Credential
            }
            catch [System.Security.Cryptography.CryptographicException] {
                if ($GLOBAL:dry_var_global_SuppressInteractivePrompts) {
                    throw "CryptographicException: Credential '$Alias' in '$EnvConfig' could not be decrypted - probably not created on this system"
                }
                else {
                    ol w "CryptographicException: Credential '$Alias' in '$EnvConfig' was probably not created on this system - prompting for correct credential. You may suppress with -SuppressInteractivePrompts"
                    return ($This.PromptForCredential($Alias,$EnvConfig,$GLOBAL:dry_var_global_Configuration.CredentialsType))
                }
            }
            catch { 
                throw "Failed to get credential '$Alias' in '$EnvConfig'"
            }
        }
        catch {
            <#   
                $PSCmdLet.ThrowTerminatingError($_) in classes generates the 'Not 
                all code paths returns value within method' in classes other than 
                'void' - using 'throw $_' instead 
            #>
            throw $_
        }
    }

    [PSCredential] GetCredentialFromAnsibleVault(
        [String] $Alias,
        [String] $EnvConfig,
        [PSCustomObject] $CredObject) {
        #! just a placeholder - not implemented
        try {
            try {
                if (($CredObject.encryptedstring).Trim() -eq '') {
                    throw "Empty encryptedstring for '$Alias' in '$EnvConfig'"
                }
                $SecureString = ConvertTo-SecureString -String $CredObject.encryptedstring -ErrorAction 'Stop'
                [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($CredObject.UserName, $SecureString)
                
                if ($GLOBAL:dry_var_global_ShowPasswords) {
                    ol w @("Credential: $Alias ($EnvConfig)","$($CredObject.UserName) ==> $($Credential.GetNetworkCredential().Password)")
                }
                else {
                    ol i @("Credential: $Alias ($EnvConfig)","$($CredObject.UserName)")
                }
                return $Credential
            }
            catch [System.Security.Cryptography.CryptographicException] {
                if ($GLOBAL:dry_var_global_SuppressInteractivePrompts) {
                    throw "CryptographicException: Credential '$Alias' in '$EnvConfig' could not be decrypted - probably not created on this system"
                }
                else {
                    ol w "CryptographicException: Credential '$Alias' in '$EnvConfig' was probably not created on this system - prompting for correct credential. You may suppress with -SuppressInteractivePrompts"
                    return ($This.PromptForCredential($Alias,$EnvConfig,$GLOBAL:dry_var_global_Configuration.CredentialsType))
                }
            }
            catch { 
                throw "Failed to get credential '$Alias' in '$EnvConfig'"
            }
        }
        catch {
            <#   
                $PSCmdLet.ThrowTerminatingError($_) in classes generates the 'Not 
                all code paths returns value within method' in classes other than 
                'void' - using 'throw $_' instead 
            #>
            throw $_
        }
    }

    [PSCustomObject] GetCredentialMatch(
        [String]$Alias,
        [String]$EnvConfig) {
        try {
            return @($This.Credentials | Where-Object {
                ($_.Alias -eq $Alias) -and ($_.EnvConfig -eq $EnvConfig)
            })
        }
        catch {
            throw $_
        }
    }

    [Bool] TestCredential(
        [String]$Alias,
        [String]$EnvConfig) {
        try {
            $CredentialMatches = @($This.Credentials | Where-Object {
                ($_.Alias -eq $Alias) -and ($_.EnvConfig -eq $EnvConfig)
            })
            if ($CredentialMatches.count -gt 1) {  
                throw "Multiple credentials '$Alias' in '$EnvConfig'" 
            }
            elseif ($CredentialMatches.count -eq 0) { 
                return $false 
            }
            else { 
                return $true 
            }
        }
        catch { 
            throw $_ 
        }
    }
}