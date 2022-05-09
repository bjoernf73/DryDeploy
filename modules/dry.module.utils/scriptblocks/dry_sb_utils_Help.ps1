[scriptblock]$dry_sb_utils_Help = {
    [CmdLetBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(HelpMessage="Specify one or more categories of utilities to show help from. If unset, shows help for all categories")]
        [ValidateSet('Strings','FileSystem',$null, 'All')]
        [System.String[]]$Category
    )
    try {
        if (($null -eq $Category) -or ($Category -contains 'All')) {
            $Category = @('All')
        }
        switch ($Category[0]) {
            'All' {
                ol i "Showing help for all DryUtils" -sh
            }
            Default {
                ol i "Showing help for DryUtils categories: $Category" -sh
            }
        }
        ol i " "
        $Category.ForEach({
            switch ($_) {
                {$_ -in @('All','Strings')} {
                    ol i @('Method','NewRandomHex') -sh
                    ol i @('Description','Creates a random string, using only the hexadecimal numeral system, of a length specified by the parameter ''-Length''. If you don''t specify a length, I''ll default to a lemgth of 25')
                    ol i @('-Length','an integer specifying the length of the random hex')
                    ol i ' ' 

                }
                {$_ -in @('All','FileSystem')} {
                    ol i @('Method','FileSystem_ResolveFullPath') -sh
                    ol i @('Description','Resolves the full path of an item. Whenever you pass in a path to a function, be it relative or other, the function will try to resolve it''s item, returning it''s FullNAme as a String, PathObject, DirectoryInfo or FileInfo. If the preexistance of the item is uncertain, you should always ask for a string to be returned. If the item should be an existing directory, you should ask for a ''DirectoryInfo'' returnvalue. If the item should be an existing file, you should ask for a ''FileInfo'' returnvalue ')
                    
                }
            }
        })
    }
    catch {
        throw $_
    }
    finally {
    }
}