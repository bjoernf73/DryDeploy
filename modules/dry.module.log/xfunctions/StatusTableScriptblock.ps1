$StatusScriptBlock = [ScriptBlock]{
    param(
        $Path,
        [int]$IntervalSeconds = 15)
    
    try {
        Clear-Host
        $Always = $true
        $Position = [System.Management.Automation.Host.Coordinates]::new(0,0)
        do {
            # Get the contents
            $Object = Get-Content -Path $Path -ErrorAction Stop | 
            ConvertTo-Json -ErrorAction Stop -Depth 50
             
            Write-Host "D r y D e p l o y  -  S T A T U S"
            Write-Host ""
            $Object | Format-Table | Out-String
            Start-Sleep -Seconds $IntervalSeconds
        }
        while ($Always -eq $true)  
    }
    catch {
        throw $_
    }
}


# Create the file
 

$StatusObject | ConvertTo-Json | Out-File -FilePath 'C:\GITs\NoGit\test2.json' -Encoding UTF8 -Force