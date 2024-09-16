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

<#
  .SYNOPSIS
  Sets the logging options for the module dry.module.log.

  .DESCRIPTION
  The dry.module.log module exports the function 'Out-DryLog' that is universally
  used in the DryDeploy project. The function logs and manages text displayed on
  the console. Set-DryLoggingOptions defines hard coded defaults for all Out-DryLog 
  options. DryDeploy's SystemOptions.json may define one or more options that will 
  override the default options. Lastly, the user may define a UserOptions.json that 
  may define one or more options that will override both the systemoptions and the
  default options.

  .PARAMETER SystemConfig
  A logging options object defined by the system. Any value defined in the 
  SystemConfig overrides values defined by default. 

   .PARAMETER UserConfig
  A logging options object defined by the user. Any value defined in the UserConfig
  overrides values defined by default and by the system.

  .INPUTS
  None. You cannot pipe objects to Set-DryLoggingOptions

  .OUTPUTS
  None. Set-DryLoggingOptions does not generate any output.

#>
function Set-DryLoggingOptions {
    [cmdletbinding()]
    param (
        [PSObject] $SystemConfig,
        [PSObject] $UserConfig,
        [String]   $WorkingDirectory,
        [String]   $ArchiveDirectory,
        [Switch]   $NoLog
    )

    try {
        # The function defines all it's Defaults, then apply the SystemConfig, then the UserConfig, then relevant command line options
        $LoggingOptions = [PSCustomObject]@{
            log_to_file                = $true
            path                       = Join-Path -Path $WorkingDirectory -ChildPath 'DryDeploy.log'
            console_width_threshold    = 70
            warn_on_too_narrow_console = $true
            array_first_element_length = 45
            post_buffer                = 3
            # [system.consolecolor]::Black, DarkBlue, DarkGreen, DarkCyan, DarkRed, DarkMagenta, DarkYellow, Gray, DarkGray, Blue, Green, Cyan, Red, Magenta, Yellow, White
            verbose     = [PSCustomObject]@{ foreground_color = 'Yellow';     background_color = $null; display_location = $true;  text_type = 'verbose:' }
            debug       = [PSCustomObject]@{ foreground_color = 'DarkYellow'; background_color = $null; display_location = $true;  text_type = 'debug:  ' }
            warning     = [PSCustomObject]@{ foreground_color = 'Yellow';     background_color = $null; display_location = $true;  text_type = 'warning:' }
            information = [PSCustomObject]@{ foreground_color = 'White';      background_color = $null; display_location = $false; text_type = '        ' }
            error       = [PSCustomObject]@{ foreground_color = 'Red';        background_color = $null; display_location = $true;  text_type = 'error:  ' }
            input       = [PSCustomObject]@{ foreground_color = 'Blue';       background_color = $null; display_location = $true;  text_type = '> ' }
            success     = [PSCustomObject]@{ foreground_color = 'Green';      background_color = $null; display_location = $false; text_type = 'success:' ;  status_text = 'Success'}
            fail        = [PSCustomObject]@{ foreground_color = 'Red';        background_color = $null; display_location = $false; text_type = 'fail:   ' ;  status_text = 'Fail'   }
        }
        

        $Streams  = @('verbose','debug','warning','information','error','input','success','fail')

        # set properties defined by the system
        if ($null -ne $SystemConfig.log_to_file)                {$LoggingOptions.log_to_file =                $SystemConfig.log_to_file}
        if ($null -ne $SystemConfig.path)                       {$LoggingOptions.path =                       $SystemConfig.path}
        if ($null -ne $SystemConfig.console_width_threshold)    {$LoggingOptions.console_width_threshold =    $SystemConfig.console_width_threshold}
        if ($null -ne $SystemConfig.warn_on_too_narrow_console) {$LoggingOptions.warn_on_too_narrow_console = $SystemConfig.warn_on_too_narrow_console}
        if ($null -ne $SystemConfig.array_first_element_length) {$LoggingOptions.array_first_element_length = $SystemConfig.array_first_element_length}
        if ($null -ne $SystemConfig.post_buffer)                {$LoggingOptions.post_buffer =                $SystemConfig.post_buffer}

        $Streams.foreach({
            if ($null -ne $SystemConfig."$_".foreground_color) {$LoggingOptions."$_".foreground_color = $SystemConfig."$_".foreground_color}
            if ($null -ne $SystemConfig."$_".background_color) {$LoggingOptions."$_".background_color = $SystemConfig."$_".background_color}
            if ($null -ne $SystemConfig."$_".display_location) {$LoggingOptions."$_".display_location = $SystemConfig."$_".display_location}
            if ($null -ne $SystemConfig."$_".text_type)        {$LoggingOptions."$_".text_type =        $SystemConfig."$_".text_type}
            
            # success and fail also have a status_text property
            if ($_ -in @('success','fail')) {
                if ($null -ne $SystemConfig."$_".status_text)  {$LoggingOptions."$_".status_text =      $SystemConfig."$_".status_text}
            }
        })

        # set properties defined by the user
        if ($null -ne $UserConfig.log_to_file)                {$LoggingOptions.log_to_file =                $UserConfig.log_to_file}
        if ($null -ne $UserConfig.path)                       {$LoggingOptions.path =                       $UserConfig.path}
        if ($null -ne $UserConfig.console_width_threshold)    {$LoggingOptions.console_width_threshold =    $UserConfig.console_width_threshold}
        if ($null -ne $UserConfig.warn_on_too_narrow_console) {$LoggingOptions.warn_on_too_narrow_console = $UserConfig.warn_on_too_narrow_console}
        if ($null -ne $UserConfig.array_first_element_length) {$LoggingOptions.array_first_element_length = $UserConfig.array_first_element_length}
        if ($null -ne $UserConfig.post_buffer)                {$LoggingOptions.post_buffer =                $UserConfig.post_buffer}
        
        $Streams.foreach({
            if ($null -ne $UserConfig."$_".foreground_color) {$LoggingOptions."$_".foreground_color = $UserConfig."$_".foreground_color}
            if ($null -ne $UserConfig."$_".background_color) {$LoggingOptions."$_".background_color = $UserConfig."$_".background_color}
            if ($null -ne $UserConfig."$_".display_location) {$LoggingOptions."$_".display_location = $UserConfig."$_".display_location}
            if ($null -ne $UserConfig."$_".text_type)        {$LoggingOptions."$_".text_type =        $UserConfig."$_".text_type}
            
            # success and fail also have a status_text property
            if ($_ -in @('success','fail')) {
                if ($null -ne $UserConfig."$_".status_text)  {$LoggingOptions."$_".status_text =      $UserConfig."$_".status_text}
            }
        })
    
        # nolog may be specified on the command line and overrides any property log_to_file specified other places
        if ($nolog) {
            $LoggingOptions.log_to_file = $false
        }
        Set-Variable -Name LoggingOptions -Value $LoggingOptions -Scope GLOBAL

        # Make path to logfile global, archive existing log and create new log file
        if (($LoggingOptions.path) -and ($LoggingOptions.log_to_file -eq $true)) {
            if (Test-Path -Path $LoggingOptions.path -ErrorAction SilentlyContinue) {
                Save-DryArchiveFile -ArchiveFile $LoggingOptions.path -ArchiveFolder $ArchiveDirectory     
            }
            New-Item -Path $LoggingOptions.path -ItemType File -Force | Out-Null
        }
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {

    }
}