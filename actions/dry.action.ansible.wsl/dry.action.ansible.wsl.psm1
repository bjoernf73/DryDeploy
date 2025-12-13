$Functions = Resolve-Path -Path "$PSScriptRoot\functions\*.ps1" -ErrorAction Stop
foreach($function in $Functions){
    . $function.path
}