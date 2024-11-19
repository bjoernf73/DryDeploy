 # TestDepHash tests if the CalcDepHash equals the stored depencency hash
 [scriptblock]$dry_core_sb_configcombo_testdephash = {
    [CmdLetBinding()]
    [OutputType([Bool])]
    param (
        [Parameter(Mandatory,HelpMessage="To determine which depdencies_hash to compare with")]
        [ValidateSet('environment','module','system')]
        [string]$Type
    )
    try {
        ol d "Testing dependencies hash for",$Type
        switch ($type) {
            'environment' {
                $Dependencies = $this.envconfig.dependencies
                $StoredHash = $This.envconfig.dependencies_hash
            }
            'module' {
                $Dependencies = $This.moduleconfig.dependencies
                $StoredHash = $This.moduleconfig.dependencies_hash
            }
            'system' {
                $Dependencies = $This.systemconfig.dependencies
                $StoredHash = $This.systemconfig.dependencies_hash
            }
        }
        [string]$ActualHash = $This.CalcDepHash($Dependencies)
        ol d 'Actual hash',$ActualHash
        ol d 'Stored hash',$StoredHash
        if ($ActualHash -eq $StoredHash) {
            return $true
        }
        else {
            return $false
        } 
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}