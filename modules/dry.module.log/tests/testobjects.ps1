$L = [PSCustomObject]@{
    log_to_file                = $true;
    path                       = ("$($ENV:LOCALAPPDATA)\DryDeploy\DryDeploy.log").Replace('\','\\');
    left_column_width          = 30;
    console_width_threshold    = 70;
    post_buffer                = 3;
    array_first_element_length = 45;
    verbose     = [PSCustomObject]@{ foreground_color = 'Cyan';     background_color = $null; display_location = $true;  text_type = 'VERBOSE:' }
    debug       = [PSCustomObject]@{ foreground_color = 'DarkCyan'; background_color = $null; display_location = $true;  text_type = 'DEBUG:  ' }
    warning     = [PSCustomObject]@{ foreground_color = 'Yellow';   background_color = $null; display_location = $true;  text_type = 'WARNING:' }
    information = [PSCustomObject]@{ foreground_color = 'White';    background_color = $null; display_location = $false; text_type = '        ' }
    error       = [PSCustomObject]@{ foreground_color = 'Red';      background_color = $null; display_location = $true;  text_type = 'ERROR:  ' }
    success     = [PSCustomObject]@{ foreground_color = 'Green';    background_color = $null; display_location = $false; text_type = '        ' ;  status_text = 'Success'}
    fail        = [PSCustomObject]@{ foreground_color = 'Red';      background_color = $null; display_location = $false; text_type = '        ' ;  status_text = 'Fail'   }
}
$L | Add-Member -MemberType NoteProperty -Name TestArr -Value @('test1','test2',6)
$L | Add-Member -MemberType NoteProperty -Name ObjTestArr -Value @('test1','test2',6,[PSCustomObject]@{'p1'='en property'; p2=5})