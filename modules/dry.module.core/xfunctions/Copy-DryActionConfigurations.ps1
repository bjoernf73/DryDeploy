<#
 This module provides core functionality for DryDeploy.


#>

function Copy-DryActionConfigurations{
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ConfigSourcePath,

        [Parameter(Mandatory)]
        [string]$ConfigTargetPath,

        [Parameter()]
        [string]$ConfigOSSourcePath
    )

    try{
        # Make sure TargetFolderPath is empty
        if(Test-Path -Path $ConfigTargetPath -ErrorAction Ignore){
            ol w "The Target temporary directory exists - removing contents"
            Remove-Item -Path "$ConfigTargetPath\*" -Recurse -Force -Confirm:$false
            Start-Sleep -Seconds 1
        }
        ol i "Copy target","$ConfigTargetPath"

        if($ConfigSourcePath -ne ''){
            ol i "Role source","$ConfigSourcePath"
            # Copy all Role configuration files to $ConfigTargetPath
            ol v "& robocopy.exe `"$ConfigSourcePath`" `"$ConfigTargetPath`" /E"
            & robocopy.exe "$ConfigSourcePath" "$ConfigTargetPath" /E  *>&1 |
            Tee-Object -Variable RoboOutput |
            Out-Null

            if($LASTEXITCODE -gt 7){
                ol w "Error occurred copying files - robocopy exit code","$LASTEXITCODE"
                foreach($Line in $RoboOutput){
                    ol w "$Line"
                }
                throw "Error occurred copying files. Exit code: $LASTEXITCODE"
            }
            else{
                $LASTEXITCODE = 0
                $GLOBAL:LASTEXITCODE = 0
                foreach($Line in $RoboOutput){
                    ol v "$Line"
                }
            }
            Remove-Variable -Name RoboOutput -ErrorAction Ignore
        }
        else{
            ol i "Role source","(none)"
        }

        if($ConfigOSSourcePath){
            ol i "Copy including OS configs from source","$ConfigOSSourcePath"
            ol v "& robocopy.exe `"$ConfigOSSourcePath`" `"$ConfigTargetPath`" /E"
            & robocopy.exe "$ConfigOSSourcePath" "$ConfigTargetPath" /E  *>&1 |
            Tee-Object -Variable RoboOutput |
            Out-Null

            if($LASTEXITCODE -gt 7){
                ol w "Error occurred copying files. Exit code","$LASTEXITCODE"
                foreach($Line in $RoboOutput){
                    ol w "$Line"
                }
                throw "Error occurred copying files. Exit code: $LASTEXITCODE"
            }
            else{
                foreach($Line in $RoboOutput){
                    ol v "$Line"
                }
            }
            Remove-Variable -Name RoboOutput -ErrorAction Ignore
        }
    }
    catch{
        $PSCmdlet.ThrowTerminatingError($_)
    }
}