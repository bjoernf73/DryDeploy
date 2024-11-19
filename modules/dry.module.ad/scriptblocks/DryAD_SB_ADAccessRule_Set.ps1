<#  
    This is an AD Config module for use with DryDeploy, or by itself.
    Copyright (C) 2021  Bjørn Henrik Formo (bjornhenrikformo@gmail.com)
    LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.ad/main/LICENSE

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

[ScriptBlock]$DryAD_SB_ADAccessRule_Set = {
    [CmdletBinding()]
    param (
       
        [Parameter(Position = 0)]
        [string]
        $Path,
     
        [Parameter(Position = 1)]
        [string]
        $TargetName,

        [Parameter(Position = 2)]
        [string]
        $TargetType,

        [Parameter(Position = 3)]
        [String[]]
        $ActiveDirectoryRights,

        [Parameter(Position = 4)]
        [System.Security.AccessControl.AccessControlType]
        $AccessControlType,

        [Parameter(Position = 5)]
        [string]
        $ObjectType,

        [Parameter(Position = 6)]
        [string]
        $InheritedObjectType,

        [Parameter(Position = 7)]
        [string]
        $ActiveDirectorySecurityInheritance,

        [Parameter(Position = 8)]
        [string]
        $ExecutionType,

        [Parameter(Position = 9)]
        [string]
        $Server
    )
    try {
        $ReturnError = $null
        $ReturnValue = $false
        $DebugReturnStrings = @("Entered Scriptblock")
        $DebugReturnStrings += @("'Path'                               = '$Path'")
        $DebugReturnStrings += @("'TargetName'                         = '$TargetName'")
        $DebugReturnStrings += @("'TargetType'                         = '$TargetType'")
        $DebugReturnStrings += @("'ActiveDirectoryRights'              = '$ActiveDirectoryRights'")
        $DebugReturnStrings += @("'AccessControlType'                  = '$AccessControlType'")
        $DebugReturnStrings += @("'ObjectType'                         = '$ObjectType'")
        $DebugReturnStrings += @("'InheritedObjectType'                = '$InheritedObjectType'")
        $DebugReturnStrings += @("'ActiveDirectorySecurityInheritance' = '$ActiveDirectorySecurityInheritance'")
        $DebugReturnStrings += @("'ExecutionType'                      = '$ExecutionType'")
        $DebugReturnStrings += @("'Server'                             = '$Server'")
        
        # Remove any blank optional parameter value to ensure correct constructor of System.DirectoryServices.ActiveDirectoryAccessRule
        if ($ObjectType -eq '') { 
            $DebugReturnStrings += "Removing 'ObjectType' (it is blank)"
            Remove-Variable -Name ObjectType 
        }
        if ($InheritedObjectType -eq '') { 
            $DebugReturnStrings += "Removing 'InheritedObjectType' (it is blank)"
            Remove-Variable -Name InheritedObjectType 
        }
        if ($ActiveDirectorySecurityInheritance -eq '') { 
            $DebugReturnStrings += "Removing 'ActiveDirectorySecurityInheritance' (it is blank)"
            Remove-Variable -Name ActiveDirectorySecurityInheritance 
        }

        # Make sure ActiveDirectory module is loaded, so the AD drive is mounted
        if ((Get-Module | Select-Object -Property Name).Name -notcontains 'ActiveDirectory') {
            try {
                Import-Module -Name 'ActiveDirectory' -ErrorAction Stop
                $DebugReturnStrings += @("The AD PSModule was not loaded, but I loaded it successfully")
                Start-Sleep -Seconds 4
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        else {
            $DebugReturnStrings += @("The AD PSModule was already loaded in session")
        }

        # However, that is not necessarily the case. That ActiveDirectory module is a bit sloppy 
        try {
            Get-PSDrive -Name 'AD' -ErrorAction Stop | 
                Out-Null
            $DebugReturnStrings += @("The AD Drive exists already")
        }
        Catch [System.Management.Automation.DriveNotFoundException] {
            $DebugReturnStrings += @("The AD Drive does not exist - trying to create it")
            
            try {
                $NewPSDriveParams = @{
                    Name        = 'AD' 
                    PSProvider  = 'ActiveDirectory' 
                    Root        = '//RootDSE/' 
                    ErrorAction = 'Stop'
                }
                New-PSDrive @NewPSDriveParams | Out-Null
            }
            catch {
                $DebugReturnStrings += @("Failed to create the AD Drive: $($_.ToString())")
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        catch {
            $DebugReturnStrings += @("The AD Drive did not exist, and an error occurred trying to get it?")
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Make sure the AD-drive is connected to $Server. This ensures that Set-ACL operates on a Domain Controller
        # that have the OUs, groups, users or any other AD object that the configuration set creates and configures, 
        # without the need for a full AD replication to have happened 
        $ADDrive = Get-PSDrive -Name 'AD' -ErrorAction Stop
        $ADDrive.Server = "$Server"
    
        $RootDSE = Get-ADRootDSE -ErrorAction Stop
        $DomainDN = $RootDSE.defaultNamingContext

        # Create a hashtable to store the GUID value of each schema class and attribute
        $ObjectTypeGUIDs = @{}
        Get-ADObject -SearchBase ($RootDSE.SchemaNamingContext) -LDAPFilter "(schemaidguid=*)" -Properties lDAPDisplayName, schemaIDGUID -ErrorAction Stop | 
            foreach-Object {
                $ObjectTypeGUIDs[$_.lDAPDisplayName] = [System.GUID]$_.schemaIDGUID
            }
        $ObjectTypeGUIDs['All'] = [GUID]::Empty
        $DebugReturnStrings += "Success getting ObjectTypeGUIDs"

        # Create a hashtable to store the GUID value of each extended right in the forest
        $ExtendedRightsMap = @{}
        Get-ADObject -SearchBase ($RootDSE.ConfigurationNamingContext) -LDAPFilter "(&(objectclass=controlAccessRight)(rightsguid=*))" -Properties displayName, rightsGuid -ErrorAction Stop | 
            foreach-Object {
                $ExtendedRightsMap[$_.displayName] = [System.GUID]$_.rightsGuid
            }
        $DebugReturnStrings += "Success getting ExtendedRightsMap"

        # Add Domain dN to $Path if it is missing
        if ($Path -notmatch "$DomainDN$") {
            $Path = $Path + ",$DomainDN"
        }
        $PathObject = Get-ADObject -Identity $Path -ErrorAction Stop
        $DebugReturnStrings += "PathObject: $($PathObject.distinguishedName)"

        # Get the object to deletegate rights to
        switch ($TargetType) {
            'group' {
                $ADGroup = Get-ADGroup -Identity $TargetName -ErrorAction Stop -Properties SID
                [System.Security.Principal.IdentityReference]$Target = $ADGroup.SID
                

            }
            'user' {
                $ADUser = Get-ADUser -Identity $User -ErrorAction Stop -Properties SID
                [System.Security.Principal.IdentityReference]$Target = $ADUser.SID
            }
        }
        $DebugReturnStrings += "SID of the Target: $Target"

        $ObjectTypeGUID = $null
        if ($ObjectType) {
            $DebugReturnStrings += "Finding GUID of ObjectType: '$ObjectType'"
            $ObjectTypeGUID = [GUID]($ObjectTypeGUIDs.$($ObjectType))
            $DebugReturnStrings += "ObjectTypeGUID: $($ObjectTypeGUID.ToString())"
        }
        
        $InheritedObjectTypeGUID = $null
        if ($InheritedObjectType) {
            $DebugReturnStrings += "Finding GUID of InheritedObjectType: '$InheritedObjectType'"
            $InheritedObjectTypeGUID = [GUID]($ObjectTypeGUIDs.$($InheritedObjectType)) 
            $DebugReturnStrings += "InheritedObjectTypeGUID: $($InheritedObjectTypeGUID.ToString())"
        }

        foreach ($ActiveDirectoryRight in $ActiveDirectoryRights) {
            $DebugReturnStrings += "Setting ACL for right: '$ActiveDirectoryRight'"
            # Current ACL
            $ACL = Get-Acl -Path "AD:\$($PathObject.DistinguishedName)" -ErrorAction Stop
            $DebugReturnStrings += "Success getting current ACL"
            $AccessRule = $null
                
            # if $ActiveDirectoryRight is an Extended Right, then $ActiveDirectoryRight becomes "ExtendedRight",
            # the GUID of the original right becomes the $ObjectTypeGuid, and GUID of $ObjectType becomes $InheritedObjectTypeGuid
            if ($ExtendedRightsMap.ContainsKey($ActiveDirectoryRight)) {
                $DebugReturnStrings += "'$ActiveDirectoryRight' is an Extended Right"
                $InheritedObjectTypeGuid = $ObjectTypeGUID
                $ObjectTypeGuid = $ExtendedRightsMap.$($ActiveDirectoryRight)
                $ActiveDirectoryRight = "ExtendedRight"
            }
            elseif ($ActiveDirectoryRight -in 'ControlAccess','CONTROL_ACCESS') {
                $ActiveDirectoryRight = [Decimal]0x100
            }
            else {
                $DebugReturnStrings += "'$ActiveDirectoryRight' is a Standard Right"
                [System.DirectoryServices.ActiveDirectoryRights]$ActiveDirectoryRight = $ActiveDirectoryRight
            }

            # Convert to proper types
            if ($null -ne $ActiveDirectorySecurityInheritance) {
                [System.DirectoryServices.ActiveDirectorySecurityInheritance]$ActiveDirectorySecurityInheritance = $ActiveDirectorySecurityInheritance
            }

            # Now we're able to find the constructor
            if (
                ($null -eq $ActiveDirectorySecurityInheritance) -and 
                ($null -eq $ObjectTypeGUID) -and 
                ($null -eq $InheritedObjectTypeGUID)
            ) { 
                
                $DebugReturnStrings += "Constructor: 1 (Target, ActiveDirectoryRight, AccessControlType)"
                $AccessRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Target, $ActiveDirectoryRight, $AccessControlType) -ErrorAction Stop
            }
            elseif (
                ($null -ne $ActiveDirectorySecurityInheritance) -and 
                ($null -eq $ObjectTypeGUID) -and 
                ($null -eq $InheritedObjectTypeGUID)
            ) { 
                $DebugReturnStrings += "Constructor: 2 (Target, ActiveDirectoryRight, AccessControlType, ActiveDirectorySecurityInheritance)"
                $AccessRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Target, $ActiveDirectoryRight, $AccessControlType, $ActiveDirectorySecurityInheritance) -ErrorAction Stop
            }
            elseif (
                ($null -ne $ActiveDirectorySecurityInheritance) -and 
                ($null -eq $ObjectTypeGUID) -and 
                ($null -ne $InheritedObjectTypeGUID)
            ) { 
                $DebugReturnStrings += "Constructor: 3 (Target, ActiveDirectoryRight, AccessControlType, ActiveDirectorySecurityInheritance, InheritedObjectTypeGUID)"
                $AccessRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Target, $ActiveDirectoryRight, $AccessControlType, $ActiveDirectorySecurityInheritance, $InheritedObjectTypeGUID) -ErrorAction Stop
            }
            elseif (
                ($null -eq $ActiveDirectorySecurityInheritance) -and 
                ($null -ne $ObjectTypeGUID) -and 
                ($null -eq $InheritedObjectTypeGUID)
            ) { 
                $DebugReturnStrings += "Constructor: 4 (Target, ActiveDirectoryRight, AccessControlType, ObjectTypeGuid)"
                $AccessRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Target, $ActiveDirectoryRight, $AccessControlType, $ObjectTypeGuid) -ErrorAction Stop
            }
            elseif (
                ($null -ne $ActiveDirectorySecurityInheritance) -and 
                ($null -ne $ObjectTypeGUID) -and 
                ($null -eq $InheritedObjectTypeGUID)
            ) { 
                $DebugReturnStrings += "Constructor: 5 (Target, ActiveDirectoryRight, AccessControlType, ObjectTypeGuid, ActiveDirectorySecurityInheritance)"
                $AccessRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Target, $ActiveDirectoryRight, $AccessControlType, $ObjectTypeGuid, $ActiveDirectorySecurityInheritance) -ErrorAction Stop
            }
            elseif (
                ($null -ne $ActiveDirectorySecurityInheritance) -and 
                ($null -ne $ObjectTypeGUID) -and 
                ($null -ne $InheritedObjectTypeGUID)) { 
                #Type = 6
                $DebugReturnStrings += "Constructor: 6 (Target, ActiveDirectoryRight, AccessControlType, ObjectTypeGuid, ActiveDirectorySecurityInheritance, InheritedObjectTypeGUID)"
                $AccessRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Target, $ActiveDirectoryRight, $AccessControlType, $ObjectTypeGuid, $ActiveDirectorySecurityInheritance, $InheritedObjectTypeGUID) -ErrorAction Stop
            }
            else {
                throw "Unable to determine constructor"
            }

            try { 
                $DebugReturnStrings += "Trying to add ACE to current ACL"
                $ACL.AddAccessRule($AccessRule)
                $DebugReturnStrings += "Successfully added ACE to current ACL"

                $DebugReturnStrings += "Trying to submit (Set-ACL) the modified ACL"
                Set-Acl -AclObject $ACL -Path ("AD:\$($PathObject.DistinguishedName)") -ErrorAction Stop
                $DebugReturnStrings += "Successfully submitted the ACL!"
            }
            catch { 
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }

        # If we reached this, assume success
        $ReturnValue = $true
        return @($DebugReturnStrings, $ReturnValue, $ReturnError)
    }
    catch {
        $DebugReturnStrings += "Set-DryADAccessRule failed"
        $ReturnError = $_
        return @($DebugReturnStrings, $ReturnValue, $ReturnError)
    }
    finally {
        # should probably remove a bunch of stuff here
    }
}
