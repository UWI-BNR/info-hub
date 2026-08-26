# Stage 3 rate-construction release manifest

**Integrated release:** 1.0.6  
**Release date:** 26 August 2026

Install every file in this delivery together. Each included DO-file carries the
same `VERSION: 1.0.6` and `RELEASE: Stage 3 rate-construction integrated
release 1.0.6` header. Verify the SHA-256 checksum before installation where
practical.

| File | Version | SHA-256 |
|---|---:|---|
| `STAGE3_RATE_CONSTRUCTION_HANDOVER.md` | 1.0.6 | `6181d75e9ae63192c608a67b9be62db4704277f96a743af7d5348500ff31e5a6` |
| `STAGE3_RATE_CONSTRUCTION_RELEASE_REVIEW_v1_0_6.md` | 1.0.6 | `3908317801737d8086f7de440ac232a4c1f0d7eec54405d905d11e7361792a72` |
| `reference_assets/who_world_standard_2000_2025.dta` | fixed asset | `badde721ca89bab3a85e75fb3e95f2cfcf4a958ff87fab41af71137d65bc9051` |
| `scripts/stata/metrics/cvd/bnr_cvd_construct_incidence_rates_core.do` | 1.0.6 | `b1e47955d7eb96cb7e63dcf6eb0aafc19740658e3070d928e6620125e391ce99` |
| `scripts/stata/metrics/cvd/bnr_cvd_prepare_rate_reference.do` | 1.0.6 | `71a53c2d4313cbdef6d2e11b03c47e47f0ef05847b3a6ff8d750affde38602b3` |
| `scripts/stata/metrics/cvd/bnr_cvd_run_incidence_rate_estimation.do` | 1.0.6 | `d58e402bbd7b5d0b2d66d95aef9e2770e8f6abd10d6856c3ad62157930841f09` |
| `scripts/stata/metrics/cvd/tests/test_bnr_cvd_construct_incidence_rates.do` | 1.0.6 | `4844b1f8092f746d1e3d030492f9ee0da26e030938ba463f9ebda329074a9e03` |
| `scripts/stata/metrics/cvd/tests/test_bnr_cvd_prepare_rate_reference.do` | 1.0.6 | `32e8d395c2f87c9b6b5ee1aeaedad8299ae9429f02cb160cb9f44d26c88bfa21` |

The manifest intentionally does not checksum itself.
