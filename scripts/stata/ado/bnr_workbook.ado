program define bnr_workbook

    version 19

    syntax, ///
        DTAfile(string) ///
        XLSXfile(string) ///
        DATASETid(string) ///
        DATASHEET(string) ///
        METASHEET(string) ///
        VARSHEET(string)

    preserve

        confirm file "`dtafile'"
        use "`dtafile'", clear

        * ----------------------------------------------------------
        * 1. Add the data sheet
        * ----------------------------------------------------------

        export excel using "`xlsxfile'", ///
            sheet("`datasheet'") firstrow(variables) sheetmodify


        * ----------------------------------------------------------
        * 2. Build dataset metadata from structured Stata notes
        * ----------------------------------------------------------

        tempfile dataset_meta
        tempname dsmeta

        postfile `dsmeta' ///
            str40 dataset_id ///
            str80 field ///
            str2045 value ///
            using "`dataset_meta'", replace

        local n_notes : char _dta[note0]
        if "`n_notes'" == "" {
            local n_notes 0
        }

        forvalues i = 1/`n_notes' {

            local note : char _dta[note`i']
            local colon_pos = strpos(`"`note'"', ":")

            if `colon_pos' > 0 {

                local field = substr(`"`note'"', 1, `colon_pos' - 1)
                local value = substr(`"`note'"', `colon_pos' + 1, .)

                local field = strtrim(`"`field'"')
                local value = strtrim(`"`value'"')

                post `dsmeta' ///
                    (`"`datasetid'"') ///
                    (`"`field'"') ///
                    (`"`value'"')
            }
        }

        postclose `dsmeta'


        * ----------------------------------------------------------
        * 3. Build variable metadata from labels and value labels
        * ----------------------------------------------------------

        tempfile variable_meta
        tempname varmeta

        postfile `varmeta' ///
            str40 dataset_id ///
            str32 variable_name ///
            str12 storage_type ///
            str16 display_format ///
            str40 value_label ///
            str500 variable_label ///
            str2045 categories ///
            using "`variable_meta'", replace

        foreach var of varlist _all {

            local vartype   : type `var'
            local varformat : format `var'
            local varlabel  : variable label `var'
            local vallabel  : value label `var'

            local categories ""

            if "`vallabel'" != "" {

                capture quietly levelsof `var' if !missing(`var'), local(levels)

                if !_rc {
                    foreach level of local levels {
                        local lab : label `vallabel' `level'
                        local categories `"`categories'`level'=`lab'; "'
                    }
                }
            }

            post `varmeta' ///
                (`"`datasetid'"') ///
                (`"`var'"') ///
                (`"`vartype'"') ///
                (`"`varformat'"') ///
                (`"`vallabel'"') ///
                (`"`varlabel'"') ///
                (`"`categories'"')
        }

        postclose `varmeta'


        * ----------------------------------------------------------
        * 4. Export the dataset metadata sheet
        * ----------------------------------------------------------

        use "`dataset_meta'", clear

        export excel using "`xlsxfile'", ///
            sheet("`metasheet'") firstrow(variables) sheetmodify


        * ----------------------------------------------------------
        * 5. Export the variable metadata sheet
        * ----------------------------------------------------------

        use "`variable_meta'", clear

        export excel using "`xlsxfile'", ///
            sheet("`varsheet'") firstrow(variables) sheetmodify

    restore

end
