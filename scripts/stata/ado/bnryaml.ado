program define bnryaml, rclass
    version 15.1
    // ---- Minimal parse: .dta in using(), all fields required, optional outfile() ----
    syntax using/, ///
        TITLE(string) VERSION(string) CREATED(string) TIER(string) TEMPORAL(string) ///
        SPATIAL(string) DESCRIPTION(string) REGISTRY(string) CONTENT(string) ///
        CREATOR(string) LANGUAGE(string) FORMAT(string) RIGHTS(string) SOURCE(string) ///
        CONTACT(string) [ OUTFILE(string) ]

    // ---- Normalise input paths (strip outer quotes; use forward slashes) ----
    local dta `"`using'"'
    if substr("`dta'",1,1)==`"""' & substr("`dta'",-1,1)==`"""' {
        local dta = substr("`dta'", 2, strlen("`dta'")-2)
    }
    local dta = subinstr("`dta'","\","/",.)

    if "`outfile'" == "" {
        // default: write YAML next to the .dta
        local stem = regexr("`dta'","\.[dD][tT][aA]$","")
        local yml  "`stem'.yml"
    }
    else {
        local yml `"`outfile'"'
        if substr("`yml'",1,1)==`"""' & substr("`yml'",-1,1)==`"""' {
            local yml = substr("`yml'", 2, strlen("`yml'")-2)
        }
        local yml = subinstr("`yml'","\","/",.)
    }

    // ---- Write YAML (plain text) ----
    quietly file open fh using "`yml'", write replace text
    file write fh "title: `title'" _n ///
                  "version: `version'" _n ///
                  "created: `created'" _n ///
                  "tier: `tier'" _n ///
                  "temporal: `temporal'" _n ///
                  "spatial: `spatial'" _n ///
                  "description: `description'" _n ///
                  "registry: `registry'" _n ///
                  "content: `content'" _n ///
                  "creator: `creator'" _n ///
                  "language: `language'" _n ///
                  "format: `format'" _n ///
                  "rights: `rights'" _n ///
                  "source: `source'" _n ///
                  "contact: `contact'" _n ///
                  "dataset: `dta'" _n
    file close fh

    return local yml "`yml'"
    di as txt "YAML written: " as res "`yml'"
end
