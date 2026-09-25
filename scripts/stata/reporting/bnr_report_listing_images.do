* Shared, presentation-only selector for CVD report listing thumbnails.
* Version 0.2.1 (25 September 2026)
* The editable site/assets/images/listings/listing-images.csv catalogue is the
* source of the image pool. A rebuild keeps its existing image; a new report
* uses the least recently used active image.
version 19

capture program drop bnr_report_listing_images
program define bnr_report_listing_images, rclass
    version 19
    syntax, ROOT(string) TARGET1(string) [TARGET2(string)]

    local catalogue "$BNR_REPO/site/assets/images/listings/listing-images.csv"
    capture confirm file "`catalogue'"
    if _rc {
        display as error "Listing image catalogue is missing: `catalogue'"
        exit 601
    }

    preserve
    import delimited using "`catalogue'", clear varnames(1) stringcols(_all)
    keep if lower(trim(active)) == "yes"
    count
    local image_count = r(N)
    if `image_count' < 2 {
        restore
        display as error "At least two active listing images are required."
        exit 459
    }
    forvalues j = 1/`image_count' {
        local image`j' = image_file[`j']
        local alt`j' = image_alt[`j']
    }
    restore

    forvalues j = 1/`image_count' {
        capture confirm file "$BNR_REPO/site/assets/images/listings/`image`j''"
        if _rc {
            display as error "Listing image is missing: `image`j''"
            exit 601
        }
        local last`j' "0000-00-00"
    }

    * Read only the front matter of existing, published landing pages.
    foreach kind in updates annual briefings studies {
        local category_dir "`root'/`kind'"
        capture local entries : dir "`category_dir'" dirs "*"
        if _rc local entries ""
        foreach entry of local entries {
            local page "`category_dir'/`entry'/index.qmd"
            capture confirm file "`page'"
            if !_rc {
                local page_image ""
                local page_date "0000-00-00"
                local delimiters 0
                tempname page_handle
                file open `page_handle' using "`page'", read text
                file read `page_handle' line
                while r(eof) == 0 & `delimiters' < 2 {
                    * Front matter may contain quoted prose (for example, a
                    * description). Keep every line as literal macro text:
                    * evaluating it as a Stata string expression can turn the
                    * prose following its first quote into an invalid name.
                    local clean `"`macval(line)'"'
                    if `"`clean'"' == "---" local delimiters = `delimiters' + 1
                    if `delimiters' == 1 & substr(`"`clean'"', 1, 7) == "image: " {
                        local page_image = subinstr(substr(`"`clean'"', 8, .), ///
                            char(34), "", .)
                        local page_image = subinstr("`page_image'", ///
                            "/assets/images/listings/", "", .)
                    }
                    if `delimiters' == 1 & substr(`"`clean'"', 1, 6) == "date: " {
                        local page_date = subinstr(substr(`"`clean'"', 7, 10), ///
                            char(34), "", .)
                    }
                    file read `page_handle' line
                }
                file close `page_handle'

                forvalues j = 1/`image_count' {
                    if "`page_image'" == "`image`j''" {
                        if "`page_date'" > "`last`j''" local last`j' "`page_date'"
                        if "`page'" == "`target1'" local fixed1 `j'
                        if "`page'" == "`target2'" local fixed2 `j'
                    }
                }
            }
        }
    }

    if "`fixed1'" != "" local chosen1 `fixed1'
    else {
        local earliest "9999-99-99"
        forvalues j = 1/`image_count' {
            if "`last`j''" < "`earliest'" & "`fixed2'" != "`j'" {
                local earliest "`last`j''"
                local chosen1 `j'
            }
        }
    }
    return local image1 "`image`chosen1''"
    return local alt1 "`alt`chosen1''"

    if "`target2'" != "" {
        if "`fixed2'" != "" local chosen2 `fixed2'
        else {
            local earliest "9999-99-99"
            forvalues j = 1/`image_count' {
                if "`last`j''" < "`earliest'" & `j' != `chosen1' {
                    local earliest "`last`j''"
                    local chosen2 `j'
                }
            }
        }
        if `chosen1' == `chosen2' {
            display as error "Existing annual and companion pages use the same image. Review the published pages before rebuilding."
            exit 459
        }
        return local image2 "`image`chosen2''"
        return local alt2 "`alt`chosen2''"
    }
end
