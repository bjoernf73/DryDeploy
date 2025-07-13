$Functions     = Resolve-Path -Path "$PSScriptRoot\Functions\*.ps1" -ErrorAction Stop
foreach($function in $Functions){
    . $function.Path
}