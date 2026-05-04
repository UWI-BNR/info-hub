program define bnr_yml

    version 19

    syntax, ///
        DTAfile(string) ///
        YMLfile(string) ///
        DATASETid(string)

    preserve

        confirm file "`dtafile'"
        use "`dtafile'", clear

        tempname yml
        file open `yml' using "`ymlfile'", write replace text

        * ----------------------------------------------------------
        * Dataset identity
        * ----------------------------------------------------------

        file write `yml' "schema: bnr_dataset_metadata_v1" _n
        file write `yml' "dataset_id: `datasetid'" _n
        file write `yml' "" _n

        file write `yml' "files:" _n
        file write `yml' "  dta: datasets/`datasetid'.dta" _n
        file write `yml' "  csv: datasets/`datasetid'.csv" _n
        file write `yml' "  yml: metadata/`datasetid'.yml" _n
        file write `yml' "" _n

        * ----------------------------------------------------------
        * Dataset-level metadata from structured Stata notes
        * ----------------------------------------------------------

        file write `yml' "metadata:" _n

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

                * Make field names YAML-friendly.
                local field = lower(`"`field'"')
                local field : subinstr local field " " "_", all
                local field : subinstr local field "-" "_", all
                local field : subinstr local field "/" "_", all
                local field : subinstr local field "." "_", all

                if `"`field'"' != "" & `"`value'"' != "" {
                    file write `yml' `"  `field': |-"' _n
                    file write `yml' `"    `value'"' _n
                }
            }
        }

        file write `yml' "" _n

        * ----------------------------------------------------------
        * Variable-level metadata
        * ----------------------------------------------------------

        file write `yml' "variables:" _n

        foreach var of varlist _all {

            local vartype   : type `var'
            local varformat : format `var'
            local varlabel  : variable label `var'
            local vallabel  : value label `var'

            file write `yml' "  - name: `var'" _n
            file write `yml' "    type: `vartype'" _n
            file write `yml' "    format: `varformat'" _n

            file write `yml' "    label: |-" _n
            file write `yml' `"      `varlabel'"' _n

            file write `yml' "    value_label: `vallabel'" _n

            * Observed labelled categories, written as one readable string.
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

            file write `yml' "    categories: |-" _n
            file write `yml' `"      `categories'"' _n
            file write `yml' "" _n
        }

        file close `yml'

    restore

end

