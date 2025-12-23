$DDFunctionPath = "$PSScriptRoot\functions\DryDeploy.ps1"
. $DDFunctionPath

New-Alias -Name 'dry' -Value 'DryDeploy'
Export-ModuleMember -Function 'DryDeploy' -Alias 'dry'