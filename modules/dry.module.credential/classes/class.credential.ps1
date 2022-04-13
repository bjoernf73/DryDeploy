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
        [String]$GlobalConfig,
        [String]$Type,
        [PSCredential] $Credential) {
        try {
            $CredObj            = [PSCustomObject]@{
                Alias           = $Alias
                GlobalConfig    = $GlobalConfig
                Type            = $Type
                UserName        = $Credential.UserName
                encryptedstring = $Credential.Password | ConvertFrom-SecureString -ErrorAction Stop
            }
    
            if ($This.TestCredential($Alias,$GlobalConfig)) {
                ol w "Credential '$Alias' in '$GlobalConfig' exists already - removing, and adding the new instance"
            }
            $This.Credentials = $This.Credentials | 
            Where-Object { 
                (-not (($_.Alias -eq $Alias) -and ($_.GlobalConfig -eq $GlobalConfig)))
            }
            $This.Credentials += @($CredObj)
            $This.WriteToFile()
        }
        catch {
            throw $_
        }
    }

    [Void] AddCredential(
        [String]$Alias,
        [String]$GlobalConfig,
        [String]$Type,
        [String]$UserName, 
        [String]$pw) {
        try {
            [SecureString]$SecStringPassword = ConvertTo-SecureString $pw -AsPlainText -Force
            [PSCredential]$Credential        = New-Object System.Management.Automation.PSCredential ($UserName, $SecStringPassword)
            
            $CredObj            = [PSCustomObject]@{
                Alias           = $Alias
                GlobalConfig    = $GlobalConfig
                Type            = $Type
                UserName        = $Credential.UserName
                encryptedstring = $Credential.Password | ConvertFrom-SecureString -ErrorAction Stop
            }

            if ($This.TestCredential($Alias,$GlobalConfig)) {
                ol w "The Credential '$Alias' exists already - removing it, and adding the new instance"
            }
            $This.Credentials = $This.Credentials | 
            Where-Object { 
                (-not (($_.Alias -eq $Alias) -and ($_.GlobalConfig -eq $GlobalConfig)))
            }
            $This.Credentials += @($CredObj)
            $This.WriteToFile()
        }
        catch {
            throw $_
        }
    }

    [Void] AddCredentialPlaceholder(
        [String]$Alias, 
        [String]$GlobalConfig, 
        [String]$Type,
        [String]$UserName) {
        try {
            if (-not ($This.TestCredential($Alias,$GlobalConfig))) {
                ol v "The Alias '$Alias' in '$GlobalConfig' not found, adding it."
                $CredObj            = [PSCustomObject]@{
                    Alias           = $Alias
                    GlobalConfig    = $GlobalConfig
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
        [String]$GlobalConfig, 
        [String]$Type) {
        try {
            if (-not ($This.TestCredential($Alias,$GlobalConfig))) {
                ol v "The Alias '$Alias' in '$GlobalConfig' not found, adding it."
                $CredObj            = [PSCustomObject]@{
                    Alias           = $Alias
                    GlobalConfig    = $GlobalConfig
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
        [String]$GlobalConfig,
        [String]$Type) {
        try {
            [PSCredential]$PromptCredential = Get-Credential -Message "Credential '$Alias' in '$GlobalConfig'"
            $This.AddCredential($Alias,$GlobalConfig,$Type,$PromptCredential)
            return $PromptCredential
        }
        catch {
            throw $_
        }
    }

    [PSCredential] PromptForCredential(
        [String]$Alias,
        [String]$GlobalConfig,
        [String]$Type,
        [String]$UserName) {
        try {
            [PSCredential]$PromptCredential = Get-Credential -Message "Credential '$Alias' in '$GlobalConfig'" -UserName $UserName
            $This.AddCredential($Alias,$GlobalConfig,$Type,$PromptCredential)
            return $PromptCredential
        }
        catch {
            throw $_
        }
    }

    [PSCredential] GetCredential( 
        [String]$Alias,
        [String]$GlobalConfig) {
        try {
            if ($This.TestCredential($Alias,$GlobalConfig)) {
                $CredentialMatch = $This.GetCredentialMatch($Alias,$GlobalConfig)

                #! this returns 'not all code paths return value within method'...
                <#
                 switch ($CredentialMatch.Type) {
                    'hashicorpvault' {
                        return [PSCredential]($This.GetCredentialFromHashicorpVault($Alias,$GlobalConfig))
                    }
                    'ansiblevault' {
                        return [PSCredential]($This.GetCredentialFromAnsibleVault($Alias,$GlobalConfig))
                    }
                    default {
                        return [PSCredential]($This.GetCredentialFromEncryptedSecureString($Alias,$GlobalConfig))
                    }
                }
                
                #>
                if ($CredentialMatch.Type -eq 'hashicorpvault') {
                    return [PSCredential]($This.GetCredentialFromHashicorpVault($Alias,$GlobalConfig,$CredentialMatch))
                }
                elseif ($CredentialMatch.Type -eq 'ansiblevault') {
                    return [PSCredential]($This.GetCredentialFromAnsibleVault($Alias,$GlobalConfig,$CredentialMatch))
                }
                elseif ($CredentialMatch.Type -eq 'encryptedstring') {
                    return [PSCredential]($This.GetCredentialFromEncryptedSecureString($Alias,$GlobalConfig,$CredentialMatch))
                }
                else {
                    # defaulting to encryptedsecurestring
                    ol w "Unable to determine the Credential Type - defaulting to 'encryptedstring'"
                    return [PSCredential]($This.GetCredentialFromEncryptedSecureString($Alias,$GlobalConfig,$CredentialMatch))
                }       
            }
            else {
                if ($GLOBAL:SuppressInteractivePrompts) {
                    throw "Found no credential '$Alias' in '$GlobalConfig'"
                }
                else {
                    ol w "You may suppress interactive prompts with the -SuppressInteractivePrompts switch"
                    return [PSCredential]($This.PromptForCredential($Alias,$GlobalConfig,$GLOBAL:CredentialsType))
                }
            }
        }
        catch {
            throw $_
        }
    }

    [PSCredential] GetCredentialFromEncryptedSecureString(
        [String] $Alias,
        [String] $GlobalConfig,
        [PSCustomObject] $CredObject) {
        try {
            try {
                if (($null -eq $CredObject.encryptedstring) -or (($CredObject.encryptedstring).Trim() -eq '')) {
                    if (($null -ne $CredObject.UserName) -and ($CredObject.UserName.Trim() -ne '')) {
                        [PSCredential]$Credential = ($This.PromptForCredential($Alias,$GlobalConfig,$GLOBAL:CredentialsType,$CredObject.UserName))
                    }
                    else {
                        [PSCredential]$Credential = ($This.PromptForCredential($Alias,$GlobalConfig,$GLOBAL:CredentialsType))
                    }
                    
                }
                else {
                    $SecureString = ConvertTo-SecureString -String $CredObject.encryptedstring -ErrorAction 'Stop'
                    [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($CredObject.UserName, $SecureString)
                }
                
                if ($GLOBAL:ShowPasswords) {
                    ol w @("Credential: $Alias ($GlobalConfig)","$($CredObject.UserName) ==> $($Credential.GetNetworkCredential().Password)")
                }
                else {
                    ol i @("Credential: $Alias ($GlobalConfig)","$($CredObject.UserName)")
                }
                return $Credential
            }
            catch [System.Security.Cryptography.CryptographicException] {
                if ($GLOBAL:SuppressInteractivePrompts) {
                    throw "CryptographicException: Credential '$Alias' in '$GlobalConfig' could not be decrypted - probably not created on this system"
                }
                else {
                    ol w "CryptographicException: Credential '$Alias' in '$GlobalConfig' was probably not created on this system - prompting for correct credential. You may suppress with -SuppressInteractivePrompts"
                    if (($null -ne $CredObject.UserName) -and ($CredObject.UserName.Trim() -ne '')) {
                        [PSCredential]$Credential = ($This.PromptForCredential($Alias,$GlobalConfig,$GLOBAL:CredentialsType,$CredObject.UserName))
                    }
                    else {
                        [PSCredential]$Credential = ($This.PromptForCredential($Alias,$GlobalConfig,$GLOBAL:CredentialsType))
                    }
                    if ($GLOBAL:ShowPasswords) {
                        ol w @("Credential: $Alias ($GlobalConfig)","$($CredObject.UserName) ==> $($Credential.GetNetworkCredential().Password)")
                    }
                    else {
                        ol i @("Credential: $Alias ($GlobalConfig)","$($CredObject.UserName)")
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
        [String] $GlobalConfig,
        [PSCustomObject] $CredObject) {
        #! just a placeholder - not implemented
        try {
            try {
                if (($CredObject.encryptedstring).Trim() -eq '') {
                    throw "Empty encryptedstring for '$Alias' in '$GlobalConfig'"
                }
                $SecureString = ConvertTo-SecureString -String $CredObject.encryptedstring -ErrorAction 'Stop'
                [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($CredObject.UserName, $SecureString)
                
                if ($GLOBAL:ShowPasswords) {
                    ol w @("Credential: $Alias ($GlobalConfig)","$($CredObject.UserName) ==> $($Credential.GetNetworkCredential().Password)")
                }
                else {
                    ol i @("Credential: $Alias ($GlobalConfig)","$($CredObject.UserName)")
                }
                return $Credential
            }
            catch [System.Security.Cryptography.CryptographicException] {
                if ($GLOBAL:SuppressInteractivePrompts) {
                    throw "CryptographicException: Credential '$Alias' in '$GlobalConfig' could not be decrypted - probably not created on this system"
                }
                else {
                    ol w "CryptographicException: Credential '$Alias' in '$GlobalConfig' was probably not created on this system - prompting for correct credential. You may suppress with -SuppressInteractivePrompts"
                    return ($This.PromptForCredential($Alias,$GlobalConfig,$GLOBAL:CredentialsType))
                }
            }
            catch { 
                throw "Failed to get credential '$Alias' in '$GlobalConfig'"
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
        [String] $GlobalConfig,
        [PSCustomObject] $CredObject) {
        #! just a placeholder - not implemented
        try {
            try {
                if (($CredObject.encryptedstring).Trim() -eq '') {
                    throw "Empty encryptedstring for '$Alias' in '$GlobalConfig'"
                }
                $SecureString = ConvertTo-SecureString -String $CredObject.encryptedstring -ErrorAction 'Stop'
                [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($CredObject.UserName, $SecureString)
                
                if ($GLOBAL:ShowPasswords) {
                    ol w @("Credential: $Alias ($GlobalConfig)","$($CredObject.UserName) ==> $($Credential.GetNetworkCredential().Password)")
                }
                else {
                    ol i @("Credential: $Alias ($GlobalConfig)","$($CredObject.UserName)")
                }
                return $Credential
            }
            catch [System.Security.Cryptography.CryptographicException] {
                if ($GLOBAL:SuppressInteractivePrompts) {
                    throw "CryptographicException: Credential '$Alias' in '$GlobalConfig' could not be decrypted - probably not created on this system"
                }
                else {
                    ol w "CryptographicException: Credential '$Alias' in '$GlobalConfig' was probably not created on this system - prompting for correct credential. You may suppress with -SuppressInteractivePrompts"
                    return ($This.PromptForCredential($Alias,$GlobalConfig,$GLOBAL:CredentialsType))
                }
            }
            catch { 
                throw "Failed to get credential '$Alias' in '$GlobalConfig'"
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
        [String]$GlobalConfig) {
        try {
            return @($This.Credentials | Where-Object {
                ($_.Alias -eq $Alias) -and ($_.GlobalConfig -eq $GlobalConfig)
            })
        }
        catch {
            throw $_
        }
    }

    [Bool] TestCredential(
        [String]$Alias,
        [String]$GlobalConfig) {
        try {
            $CredentialMatches = @($This.Credentials | Where-Object {
                ($_.Alias -eq $Alias) -and ($_.GlobalConfig -eq $GlobalConfig)
            })
            if ($CredentialMatches.count -gt 1) {  
                throw "Multiple credentials '$Alias' in '$GlobalConfig'" 
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