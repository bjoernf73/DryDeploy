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

function Save-DryArchiveFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,HelpMessage="Path to, or file system object ([System.IO.File]) 
        of the file to archive")]
        [System.IO.FileInfo]$ArchiveFile,

        [Parameter(HelpMessage="Number of archived files to keep. I will count existing 
        archived files, and delete all but the `$ToKeep newest (based on the sortable 
        date in filename). If 0, I won't delete any old archive files")]
        [Int]$ToKeep = 15,

        [Parameter()]
        [String]$ArchiveSubFolder,

        [Parameter()]
        [String]$ArchiveFolder
    )

    $OriginalFileDirectory = Split-Path $ArchiveFile
    if ($ArchiveSubFolder) {
        # The file will be renamed and moved to a subdirectory below it's original path. 
        # Add appending '\' to make clear this is a directory
        $ArchiveFileDirectory = $OriginalFileDirectory + '\' + $ArchiveSubFolder + '\'
        # make sure the directory exists
        if (-not (Test-Path -Path $ArchiveFileDirectory -ErrorAction SilentlyContinue)) {
            New-Item -Path $ArchiveFileDirectory -ItemType Directory -ErrorAction Stop | 
            Out-Null 
        }
        else {
            # make sure the existing $ArchiveFileDirectory is a directory
            switch ((Get-Item -Path $ArchiveFileDirectory -ErrorAction Stop).PSIsContainer) {
                $true {
                    ol v "The archive directory '$ArchiveFileDirectory' exists, and is a directory"
                }
                default {
                    throw "The archive directory '$ArchiveFileDirectory' exists, but is not a directory"
                }
            }
        }
    }
    elseif ($ArchiveFolder) {
        $ArchiveFileDirectory = Get-Item -Path $ArchiveFolder
    }
    else {
        # The file will be renamed and left in it's original directory
        $ArchiveFileDirectory = $OriginalFileDirectory
    }
    $ArchiveFileName = Split-Path $ArchiveFile -leaf
    
    # Create the new file name based on the file's LastWriteTime attribute
    $ArchiveFileNewName = "ARCH_" + $(($ArchiveFile.LastWriteTime | Get-Date -format s) -replace ':','-') + "_$ArchiveFileName"
    $ArchiveFileNewFullName = Join-Path -Path $OriginalFileDirectory -ChildPath $ArchiveFileNewName

    try {
        # rename the file
        $ArchiveFile | 
        Rename-Item -NewName $ArchiveFileNewName -Confirm:$False

        # move the file if $ArchiveSubFolder
        if ($ArchiveSubFolder -or $ArchiveFolder) {
            Get-Item -Path $ArchiveFileNewFullName -ErrorAction Stop | 
            Move-Item -Destination $ArchiveFileDirectory -ErrorAction Stop
        }
        
        # removes the oldest archived files, keeping the $ToKeep newest
        $OldArchivedFiles = Get-ChildItem -Path "$ArchiveFileDirectory\*" | 
        Where-Object { 
            ($_.Name -match "^ARCH_[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{1,2}-[0-9]{1,2}-[0-9]{1,2}_") -and
            ($_.Name -like "*$ArchiveFileName")
        }

        $OldArchivedFilesList = [System.Collections.Generic.List[PSObject]]::New()
        foreach ($OldArchivedFile in $OldArchivedFiles) {
            $OldArchivedFilesList.Add([PSCustomObject]@{
                'File'="$OldArchivedFile"
                'Date'="$(($OldArchivedFile.BaseName -Split '_')[1])"
            })
        }
        
        $SortedOldArchivedFilesList = [System.Collections.Generic.List[PSObject]]::New()
        $OldArchivedFilesList | 
        Sort-Object -Property 'Date' | 
        foreach-Object {
            $SortedOldArchivedFilesList.Add($_)
        }
        While ($SortedOldArchivedFilesList.count -gt $ToKeep) {
            ($SortedOldArchivedFilesList[0]).File | 
            Remove-Item -Force -Confirm:$False -ErrorAction 'Stop'
            $SortedOldArchivedFilesList.RemoveAt(0)
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    Finally {
        @('OldArchivedFilesList',
            'SortedOldArchivedFilesList',
            'OldArchivedFiles'
        ).foreach({
            Remove-Variable -Name $_ -ErrorAction Ignore
        })
    }
}