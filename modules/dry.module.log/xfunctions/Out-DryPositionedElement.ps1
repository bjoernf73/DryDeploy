# Må testes med: 
# - lists;  of objects, list of strings, 
# - objects; simple one-level-psobject and complex psobjects containing strings, arrays of psobjetcs, array of strings, and so on
function Out-DryPositionedElement {
    [CmdletBinding(DefaultParameterSetName="updatescreen")]
    [Alias("odpe")]
    param (
        [Alias("obj")]
        [Parameter(ParameterSetName="updatescreen",Mandatory,
        HelpMessage="The Object to output (to screen). May be a string, a list ([System.Collections.Generic.List[]]) or array, or a PSCustomObject")]
        [PSObject]$Object,

        [Alias("alias")]
        [Parameter(ParameterSetName="updatescreen",Mandatory,
        HelpMessage="The identifying name of the Object. The Name and it's position will be stored in a variable `$dry_var_global_PositionedElements 
        in the global scope, so on subsequent calls, the initial position of `$Name will be used. If `$Position, then that will be used and an entry
        with the corresponding `$Name will be created in `$dry_var_global_PositionedElements, or overwritten if it exists. If not `$Position, and an 
        entry with the corresponding `$Name in `$dry_var_global_PositionedElements does not exist, the current cursor position will be used and an entry
        created")]
        [string]$Name,

        [Parameter(ParameterSetName="updatescreen",
        HelpMessage="Output as a List (Format-List) instead of a table (Format-Table) which is the default")]
        [Switch]$List,

        [Parameter(ParameterSetName="updatescreen",
        HelpMessage="Use this position, and overwrite any saved position")]
        [System.Management.Automation.Host.Coordinates]$Position,

        [Parameter(ParameterSetName="updatescreen",
        HelpMessage="Remove this objects position from the `$dry_var_global_PositionedElements list")]
        [Switch]$Scratch,

        [Alias("fore")]    
        [AllowNull()]
        [Parameter(ParameterSetName="updatescreen",HelpMessage="Override the global options and the default fore color")]
        [Parameter(ParameterSetName="array",HelpMessage="Override the global options and the default fore color")]
        [System.ConsoleColor]$ForegroundColor,

        [Alias("back")]
        [AllowNull()]
        [Parameter(ParameterSetName="updatescreen",HelpMessage="Override the global options and the default back color")]
        [Parameter(ParameterSetName="array",HelpMessage="Override the global options and the default fore color")]
        [System.ConsoleColor]$BackgroundColor
    )

    try {
        # Store the initial position
        $InitialPosition = $Host.UI.RawUI.Cursorposition

        # Create the globally scoped variable that holds positions
        if ($null -eq $GLOBAL:dry_var_global_PositionedElements) {
            $GLOBAL:dry_var_global_PositionedElements = [System.Collections.Generic.List[PSCustomObject]]::new()
        }

        if ($Scratch) {
            :ScratchLoop foreach ($PositionedElement in $GLOBAL:dry_var_global_PositionedElements) { 
                if ($PositionedElement.Name -eq $Name) { 
                    $GLOBAL:dry_var_global_PositionedElements.Remove($PositionedElement)
                    break ScratchLoop
                }
            }
        }
        
        # Determine the position of the element
        if ($Position) {
            $PositionObj = New-Object -TypeName PSCustomObject -Property @{
                Name     = $Name
                Position = $Position
            }
            $GLOBAL:dry_var_global_PositionedElements = $GLOBAL:dry_var_global_PositionedElements | Where-Object { $_.Name -ne $Name}
            $GLOBAL:dry_var_global_PositionedElements.Add($PositionObj)
        }
        else {
            if ($null -eq ($GLOBAL:dry_var_global_PositionedElements | Where-Object { $_.Name -eq $Name})) {
                [System.Management.Automation.Host.Coordinates]$Position = $Host.UI.RawUI.Cursorposition
                $PositionObj = New-Object -TypeName PSCustomObject -Property @{
                    Name     = $Name
                    Position = $Position
                }
                $GLOBAL:dry_var_global_PositionedElements.Add($PositionObj)
            }
            else {
                [System.Management.Automation.Host.Coordinates]$Position = ($GLOBAL:dry_var_global_PositionedElements | Where-Object { $_.Name -eq $Name}).Position
            }
        }

        # Set params to Write-Host
        $WriteHostParams = @{}
        if ($ForegroundColor) {
            $WriteHostParams+=@{
                ForegroundColor = $ForegroundColor
            }
        }
        if ($BackgroundColor) {
            $WriteHostParams+=@{
                BackGroundColor = $BackgroundColor
            }
        }
        if ($List) {
            $Host.UI.RawUI.Cursorposition = $Position
            ($Object | Format-List | Out-String) | Write-Host @WriteHostParams
        }
        else {
            $Host.UI.RawUI.Cursorposition = $Position
            ($Object | Format-Table | Out-String) | Write-Host @WriteHostParams
        }

    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    finally {
        $Host.UI.RawUI.Cursorposition = $InitialPosition
    }
}