<# 
 This module provides utility functions for use with DryDeploy.

 Copyright (C) 2021  Bjorn Henrik Formo (bjornhenrikformo@gmail.com)
 LICENSE: https://raw.githubusercontent.com/bjoernf73/DryDeploy/master/LICENSE
#>


<#
.SYNOPSIS
Tests a Directory for specific properties 

.DESCRIPTION
Tests a directory for specific properties, like does it exist, 
is it empty and so on. Can also create the directory if it does 
not exist 
   
.PARAMETER EmptyOrNotExist
Will only pass if the directory either a. does exist, or, if it
does, b. it is empty. else, an error is thrown

.PARAMETER NotExist
Will only pass if the directory either does not exist 

.PARAMETER Exist
Will only pass if the directory exists

.PARAMETER Create
If all tests passes, the directory will be created if it does 
not exist

.EXAMPLE
Test-DryUtilsDirectory -Path 'c:\test' -EmptyOrNotExist -Create
If the directory does not exist, or it it exists but is empty, 
the test passes. If the directory does not exist, it will be 
created.  

.EXAMPLE
Test-DryUtilsDirectory -Path 'c:\test' -NotExist
If the directory does not exist the test passes.

.EXAMPLE
Test-DryUtilsDirectory -Path 'c:\test' -Exist
If the directory exists, the test passes. If it does not,
the test failes
#>
function Test-DryUtilsDirectory{
    param(
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo]$Path,

        [Parameter(HelpMessage="Will pass if the directory does not exist, 
        or if it exists but is empty")]
        [Switch]$EmptyOrNotExist,

        [Parameter(HelpMessage="Will pass if the directory does not exist")]
        [Switch]$NotExist,

        [Parameter(HelpMessage="Will pass if the directory exists")]
        [Switch]$Exist,

        [Parameter(HelpMessage="Will create the directory if it does not
        already exist")]
        [Switch]$Create
    )
    
    try{
        $Validated = $false
        
        if($EmptyOrNotExist){
            # Will pass if the directory does not exist, or if it exists and is empty
            if(-not (Test-Path -Path $Path -ErrorAction Ignore)){
                $Validated = $true
            }
            elseif(
                (Test-Path -Path $Path -ErrorAction Ignore) -and
                ((Get-Item -Path $Path).PSisContainer -eq $true) -and
                ($null -eq (Get-ChildItem -Path $Path ))
            ){
                $Validated = $true
            }

            if($Validated -eq $false){
                throw "Could not validate test on '$Path'"
            }
        }

        if($NotExist){
            # Will pass if the directory does not exist
            if(-not (Test-Path -Path $Path -ErrorAction Ignore)){
                $Validated = $true
            }

            if($Validated -eq $false){
                throw "Could not validate test on '$Path'"
            }
        }

        if($Exist){
            # Will pass if the directory exists
            if(
                (Test-Path -Path $Path -ErrorAction Ignore) -and 
                ((Get-Item -Path $Path).PSisContainer -eq $true)
            ){
                $Validated = $true
            }

            if($Validated -eq $false){
                throw "Could not validate test on '$Path'"
            }
        }

        # Post actions
        if($Create){
            if(-not (Test-Path -Path $Path -ErrorAction Ignore)){
                New-Item -Path $Path -ItemType Directory -ErrorAction Stop |
                Out-Null
            }
        }
    }
    catch{
        ol w "The test(s) on directory '$Path' failed"
        $PSCmdlet.ThrowTerminatingError($_)
    }
}