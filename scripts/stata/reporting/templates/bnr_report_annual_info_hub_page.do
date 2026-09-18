/*******************************************************************************
DO-FILE: bnr_report_annual_info_hub_page.do
VERSION: 1.1.0 (18 September 2026)
PURPOSE: Insert the penultimate BNR Information Hub promotional page in the
         annual CVD report. The public-health update remains the final page.

CALLER:
  bnr_report_annual_s1_build.do only, after the year-specific Special chapter
  and before the extractable public-health update.

BOUNDARY:
  This is a public-facing information page. It reads no data, calculates no
  measures, changes no releases and performs no approval or publication step.
  The controlled opaque image is presentation-only and is checked by Step 1
  before PDF composition begins.
*******************************************************************************/

version 19.0

if "`info_hub_promo'" == "" {
    display as error "Information Hub page requires local info_hub_promo."
    exit 198
}
capture confirm file "`info_hub_promo'"
if _rc {
    display as error "Information Hub promotional image not found: `info_hub_promo'"
    exit 601
}

putpdf pagebreak
putpdf table hub_promo_page = (1,1), width(100%) border(all, nil)
putpdf table hub_promo_page(1,1) = image("`info_hub_promo'"), halign(center)
