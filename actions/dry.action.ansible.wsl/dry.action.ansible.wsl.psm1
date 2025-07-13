$Functions = Resolve-Path -Path "$PSScriptRoot\function\*.ps1" -ErrorAction Stop
foreach($function in $Functions){
    . $function.path
}