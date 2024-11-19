Using NameSpace System.Management.Automation
Using NameSpace System.Management.Automation.Runspaces
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
function Copy-DryADFilesToRemoteTarget {
    [CmdletBinding(DefaultParameterSetName = 'Local')]
    param (
        [Parameter(Mandatory)]
        [string]
        $TargetPath,

        [Parameter(Mandatory)]
        [string]
        $SourcePath,

        [Parameter(Mandatory, ParameterSetName = 'Remote')]
        [PSSession]
        $PSSession
    )
    
    try {
        ol v @('Copy Type', "$($PSCmdlet.ParameterSetName)")
        ol v @('Source Path', "$SourcePath")
        ol v @('Target Path', "$TargetPath")
        # The PS Progress Bar is astonsishingly uninformative when copying multiple small 
        # files - suppress, and bring it back to the original $ProgressPreference in Finally  
        $OriginalProgressPreference = $ProgressPreference
        
        # Remove any double backslashes and wildcards from target
        while ($TargetPath -match '\\\\') {
            $TargetPath = $TargetPath -Replace '\\\\', '\'
        }
        $TargetPathTrimmed = $TargetPath.TrimEnd('*')
        $TargetPathTrimmed = $TargetPathTrimmed.TrimEnd('\')
        $TargetPathTrimmed = $TargetPathTrimmed + '\'
        ol v @('Trimmed Target Path', "$TargetPathTrimmed")
        
        # Remove any double backslashes and wildcards from source
        while ($SourcePath -match '\\\\') {
            $SourcePath = $SourcePath -Replace '\\\\', '\'
        }
        $SourcePathTrimmed = $SourcePath.TrimEnd('*')
        $SourcePathTrimmed = $SourcePathTrimmed.TrimEnd('\')
        $SourcePathTrimmed = $SourcePathTrimmed + ('\')
        ol v @('Trimmed Source Path', "$SourcePathTrimmed")

        # Make sure the root folder exists. Copy-Item is deviously unpredictable
        $TargetDirectory = $TargetPathTrimmed.Trim('\')
        ol v @('Trying to create directory', $TargetDirectory)
        $InvokeCommandParams = @{
            ScriptBlock  = $DryAD_SB_CreateDir
            ArgumentList = @($TargetDirectory)
        }
        if ($PSSession) {
            $InvokeCommandParams += @{
                Session = $PSSession
            }
        }

        $Result = Invoke-Command @InvokeCommandParams
        switch ($Result) {
            $true {
                ol v @('Successfully created directory', $TargetDirectory)
            }
            { $Result -is [ErrorRecord] } {
                $PSCmdlet.ThrowTerminatingError($Result)
            }
            default {
                throw "Failed to create directory '$TargetDirectory'", $Result.ToString()
            }
        }

        <#
        $SourceDirectories = Get-ChildItem -Path $SourcePathTrimmed -Recurse -Directory -ErrorAction Stop
        foreach ($SourceDirectory in $SourceDirectories) {
            $TargetDirectory = $TargetPathTrimmed + $($SourceDirectory.FullName).SubString($SourcePathTrimmed.Length)
            ol d @('Trying to create directory', $TargetDirectory)
            
            $InvokeCommandParams = @{
                ScriptBlock  = $DryAD_SB_CreateDir
                ArgumentList = @($TargetDirectory)
            }
            if ($PSSession) {
                $InvokeCommandParams += @{
                    Session = $PSSession
                }
            }

            $Result = Invoke-Command @InvokeCommandParams
            switch ($Result) {
                $true {
                    ol v @('Successfully created directory', $TargetDirectory)
                }
                { $Result -is [ErrorRecord] } {
                    $PSCmdlet.ThrowTerminatingError($Result)
                }
                default {
                    throw "Failed to create directory '$TargetDirectory'", $Result.ToString()
                }
            }
        }
        #>
        
        $ProgressPreference = 'SilentlyContinue'
        $CopyItemParams = @{
            Path        = $SourcePathTrimmed
            Destination = $TargetPathTrimmed
            Recurse     = $true
            Container   = $true
            Force       = $true
            ErrorAction = 'Stop'
        }
        if ($PSSession) {
            $CopyItemParams += @{
                ToSession = $PSSession
            }
        }
         
        Copy-Item @CopyItemParams
        ol v @('Successfully copied files to directory', $TargetPathTrimmed)
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $ProgressPreference = $OriginalProgressPreference
        
        @('TargetPath',
            'TargetPathTrimmed',
            'SourcePath',
            'SourcePathTrimmed',
            'SourceDirectories',
            'TargetDirectory',
            'InvokeCommandParams',
            'Result',
            'CopyItemParams'
        ).foreach({ Remove-Variable -Name $_ -ErrorAction 'Ignore' })
    }
}
