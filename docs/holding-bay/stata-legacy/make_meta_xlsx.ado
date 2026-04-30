program define make_meta_xlsx
    version 15

    /*
        Create an Excel file with:
          - Sheet 1: data (current dataset in memory)
          - Sheet 2: dataset-level metadata from a simple YAML file
          - Sheet 3: variable-level metadata (describe-like)

        Syntax:
          make_meta_xlsx using "output.xlsx", yaml("meta.yml") ///
              [ datasheet("Data") dmetasheet("Dataset_meta") vmetasheet("Variable_meta") ]
    */

    syntax using/, YAML(string) ///
        [ DATASHEET(string) DMETASHEET(string) VMETASHEET(string) ]

    // ----- Default sheet names -----
    if "`datasheet'"  == "" local datasheet  "Data"
    if "`dmetasheet'" == "" local dmetasheet "Dataset_meta"
    if "`vmetasheet'" == "" local vmetasheet "Variable_meta"

    // ----- Clean up paths -----
    local xfile    `"`using'"'
    local yamlfile `"`yaml'"'

    // Trim whitespace
    local xfile    = trim("`xfile'")
    local yamlfile = trim("`yamlfile'")

    // Strip outer quotes if present
    local lenx : length local xfile
    if `lenx' >= 2 & substr("`xfile'",1,1) == `"""' & substr("`xfile'",`lenx',1) == `"""' {
        local xfile = substr("`xfile'",2,`lenx'-2)
    }

    local leny : length local yamlfile
    if `leny' >= 2 & substr("`yamlfile'",1,1) == `"""' & substr("`yamlfile'",`leny',1) == `"""' {
        local yamlfile = substr("`yamlfile'",2,`leny'-2)
    }

    // Normalise slashes (helps with weird \0xx issues)
    local xfile    = subinstr("`xfile'","\","/",.)
    local yamlfile = subinstr("`yamlfile'","\","/",.)

    // ------------------------------------------------------------
    // 1. Variable-level metadata (like describe)
    // ------------------------------------------------------------
    local vlist : varlist _all

    preserve
        tempfile varmeta
        clear

        local nvars : word count `vlist'
        if `nvars' == 0 {
            di as err "No variables in dataset."
            restore
            exit 498
        }

        set obs `nvars'
        gen str32  varname  = ""
        gen str12  type     = ""
        gen str16  format   = ""
        gen str32  vallabel = ""
        gen str200 varlabel = ""

        local i = 1
        foreach v of local vlist {
            replace varname = "`v'" in `i'

            local t  : type `v'
            local f  : format `v'
            local vl : value label `v'
            local lb : variable label `v'

            replace type     = "`t'"  in `i'
            replace format   = "`f'"  in `i'
            replace vallabel = "`vl'" in `i'
            replace varlabel = "`lb'" in `i'

            local ++i
        }

        save `varmeta', replace
    restore

    // ------------------------------------------------------------
    // 2. Dataset-level metadata from simple YAML (key: value)
    //    Assumes lines like:  key: value
    // ------------------------------------------------------------
    preserve
        tempfile dsetmeta
        clear
        set obs 0
        gen str80  key   = ""
        gen str200 value = ""

        // Open YAML file
        quietly file open fyaml using `"`yamlfile'"', read text
        file read fyaml line
        local n = 0

        while (r(eof) == 0) {
            local ln = strtrim("`line'")

            // Skip empty lines and comment lines starting with "#"
            if "`ln'" != "" & substr("`ln'", 1, 1) != "#" {
                local pos = strpos("`ln'", ":")
                if `pos' > 0 {
                    // Split into key and value
                    local k = strtrim(substr("`ln'", 1, `pos' - 1))
                    local v = strtrim(substr("`ln'", `pos' + 1, .))

                    // Remove leading spaces from value
                    while (strlen("`v'") > 0 & substr("`v'", 1, 1) == " ") {
                        local v = substr("`v'", 2, .)
                    }

                    // Add new observation
                    local ++n
                    set obs `n'
                    replace key   = "`k'" in `n'
                    replace value = "`v'" in `n'
                }
            }

            file read fyaml line
        }
        file close fyaml

        save `dsetmeta', replace
    restore

    // ------------------------------------------------------------
    // 3. Write Excel file
    // ------------------------------------------------------------

    // Sheet 1: main data
    export excel using `"`xfile'"', sheet("`datasheet'") ///
        firstrow(variables) replace

    // Sheet 2: dataset-level metadata
    preserve
        use `dsetmeta', clear
        export excel using `"`xfile'"', sheet("`dmetasheet'") ///
            firstrow(variables) sheetmodify
    restore

    // Sheet 3: variable-level metadata
    preserve
        use `varmeta', clear
        export excel using `"`xfile'"', sheet("`vmetasheet'") ///
            firstrow(variables) sheetmodify
    restore

end
