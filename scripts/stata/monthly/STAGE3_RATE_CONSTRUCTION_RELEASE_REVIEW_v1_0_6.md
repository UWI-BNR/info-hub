# Stage 3 rate-construction release review

**Release candidate:** 1.0.6  
**Review date:** 26 August 2026  
**Scope:** controller, calculation core, reference builder, both synthetic tests,
reference-file contract, handover and release manifest.

## Release decisions

- The exact WPP production filename is
  `wpp2024_brb_population_2010_2035_5y.dta`.
- The exact WHO production filename is
  `who_world_standard_2000_2025.dta`.
- A CVD release before December does not support a complete annual rate for its
  release year. The April 2024 release therefore produces 2010--2023 annual
  rates only.
- Five-year sex-by-age components, unknown age/sex and mixed/unallocated CVD
  remain private. Only the frozen annual public-shaped lattice is produced.
- Directly age-standardised rows carry no single numerator or denominator;
  crude rows retain both.
- Candidate and component DTAs are committed only after embedded acceptance QA
  succeeds.

## Code and workflow checks completed

| Area | Release check |
|---|---|
| Arguments | Required arguments, integer release dates and mortality/CVD ordering validated. |
| Dependencies | Every input is checked separately and reported by descriptive name. |
| Source files | Production filenames match the completed Stage 4C and Stage 4E-c outputs. |
| Event coding | `etype` 1=Stroke and 2=Heart; source sex 1=Female and 2=Male; legacy `dco==1` excluded. |
| Year scope | Analytical start fixed at 2010; target rates stop at the last complete CVD year. |
| Fallback pools | Sex-age allocation reuses the complete Stage 4E-c source-year range and its selected annual/three-year/all-years level. |
| Joint accounting | Selected composition total is checked against Stage 4E-c `selected_total_A`. |
| Denominators | 21 age groups per year/sex; 2010--2035 coverage; all=female+male. |
| Standardisation | 21 WHO groups, positive weights, normalized weight sum=1, unknown age excluded. |
| Bounds | Lower <= central <= upper for every enhanced crude and ASR row. |
| Definitions | Inclusive lower/central/upper must not fall below Primary in an identical published stratum. |
| Sex accounting | All-sex crude numerators include female, male and unknown-sex records. |
| Public-shaped lattice | Exactly 54 candidate rows per complete year; no unknown sex or mixed category. |
| Output safety | Final DTAs are not written before acceptance assertions pass. |
| Version control | Every delivered DO-file header and test reports release 1.0.6; manifest checksums are regenerated from final bytes. |

## Reference validation

The supplied assets were checked as follows:

- WPP: 1,638 rows = 26 years x 3 sex groups x 21 age groups;
- WPP coverage: 2010--2035 inclusive;
- maximum all-sex versus female+male numerical gap: below `0.000001` person;
- WHO: 21 unique age groups from 0--4 through 100+;
- WHO weights: all positive and normalized to one; and
- WPP and WHO age-group lattices: identical.

## Required user validation

The two synthetic tests must pass under Stata 19 before the private production
controller is run. The production log and aggregate QA CSV then remain subject
to review before any disclosure-control or public-promotion work begins.
