[scriptblock]$dry_sb_utils_Strings_NewRandomHex = {
    [CmdLetBinding()]
    [OutputType([System.String])]
    
    param (
        [Parameter(HelpMessage="Length of the random hex")]
        [Int]$Length = 25
    )
    try {
        $Chars = '0123456789ABCDEF'
        [String]$Random = $null
        for ($i=1; $i -le $Length; $i++)     {
            $Random += $Chars.Substring((Get-Random -Minimum 0 -Maximum 16),1)
        }
        return $Random
    }
    catch {
        throw $_
    }
    finally {
        $i = $null
        $Random = $null
    }
}