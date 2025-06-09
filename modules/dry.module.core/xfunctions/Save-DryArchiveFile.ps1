<# 
 This module provides core functionality for DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/dry.module.core/main/LICENSE
 
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

function Save-DryArchiveFile{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,HelpMessage="Path to, or file system object ([System.IO.File]) 
        of the file to archive")]
        [System.IO.FileInfo]
        $ArchiveFile,

        [Parameter(HelpMessage="Number of archived files to keep. I will count existing 
        archived files, and delete all but the `$ToKeep newest (based on the sortable 
        date in filename). If 0, I won't delete any old archive files")]
        [int]
        $ToKeep = 50,

        [Parameter(HelpMessage="The folder to move the archived file into. If not given, I'll
        default to the same folder as the original file. Don't worry, I'll fix a unique name")]
        [string]
        $ArchiveFolder
    )
    try{
        if(-not $ArchiveFolder){
            $ArchiveFolder = Split-Path -Path $ArchiveFile
        }
        $ArchiveSourceFolder = Resolve-DryUtilsFullPath -Path (Split-Path -Path $ArchiveFile)
        $ArchiveTargetFolder = Resolve-DryUtilsFullPath -Path $ArchiveFolder -Force
    
        if(-not (Test-Path -Path $ArchiveTargetFolder -ErrorAction Ignore)){
            New-Item -Path $ArchiveTargetFolder -ItemType Directory -ErrorAction Stop -Force | Out-Null
        }

        $ArchiveFileName = Split-Path $ArchiveFile -leaf
        # Create the new file name based on the file's LastWriteTime attribute
        $ArchiveFileNewName = "ARCH_" + $(($ArchiveFile.LastWriteTime | Get-Date -format s) -replace ':','-') + "_$ArchiveFileName"
        $ArchiveFileNewFullName = Join-Path -Path $ArchiveSourceFolder -ChildPath $ArchiveFileNewName
        $ArchiveFile | Rename-Item -NewName $ArchiveFileNewName -Confirm:$false
        
        if($ArchiveSourceFolder -ne $ArchiveTargetFolder){
            Get-Item -Path $ArchiveFileNewFullName -ErrorAction Stop | 
            Move-Item -Destination $ArchiveTargetFolder -ErrorAction Stop
        }

        # removes the oldest archived files, keeping the $ToKeep newest
        $OldArchivedFiles = Get-ChildItem -Path "$ArchiveTargetFolder\*" | Where-Object{ 
            ($_.Name -match "^ARCH_[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{1,2}-[0-9]{1,2}-[0-9]{1,2}_") -and
            ($_.Name -like "*$ArchiveFileName")
        }

        # only keep the $ToKeep newest files
        $OldArchivedFilesList = [System.Collections.Generic.List[PSObject]]::New()
        foreach($OldArchivedFile in $OldArchivedFiles){
            $OldArchivedFilesList.Add([PSCustomObject]@{
                'File'="$OldArchivedFile"
                'Date'="$(($OldArchivedFile.BaseName -Split '_')[1])"
            })
        }
        $SortedOldArchivedFilesList = [System.Collections.Generic.List[PSObject]]::New()
        $OldArchivedFilesList | 
        Sort-Object -Property 'Date' | 
        foreach-Object{
            $SortedOldArchivedFilesList.Add($_)
        }
        while ($SortedOldArchivedFilesList.count -gt $ToKeep){
            ($SortedOldArchivedFilesList[0]).File | 
            Remove-Item -Force -Confirm:$false -ErrorAction 'Stop'
            $SortedOldArchivedFilesList.RemoveAt(0)
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally{
        $ArchiveFolder = $null
        $ArchiveFile = $null 
        $ArchiveTargetFolder = $null
        $ArchiveSourceFolder = $null
        $ArchiveFileName = $null
        $ArchiveFileNewName = $null
        $ArchiveFileNewFullName = $null
        $OldArchivedFiles = $null 
        $OldArchivedFile = $null
        $OldArchivedFilesList = $null
        $SortedOldArchivedFilesList = $null
    }
}