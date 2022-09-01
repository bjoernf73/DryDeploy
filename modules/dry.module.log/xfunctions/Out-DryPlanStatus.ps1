# Må testes med: 
# - lists;  of objects, list of strings, 
# - objects; simple one-level-psobject and complex psobjects containing strings, arrays of psobjetcs, array of strings, and so on
[scriptblock]$OutDryPlanStatus =  {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,HelpMessage="Path to the file containing the Plan")]
        [string]$Path,

        [Parameter()]
        [PSObject]$ConfigCombo,

        [Parameter(HelpMessage="Seconds to sleep before rerunning the loop")]
        [int]$IntervalSeconds = 5
    )

    $Loop = $true
    $Mode = 'Apply'
    try {
        if (-not (Test-Path -Path $Path -ErrorAction SilentlyContinue)) {
            throw "The PlanFile '$Path' does not exist"
        }
         
        # create a loop that runs as long as there are unfinished business
        do {
            $Plan = Get-Content -Path $Path -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

            # sleep before the loop reruns
            Start-Sleep -Seconds $IntervalSeconds
        }
        while ($Loop -eq $true)
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
    }
}