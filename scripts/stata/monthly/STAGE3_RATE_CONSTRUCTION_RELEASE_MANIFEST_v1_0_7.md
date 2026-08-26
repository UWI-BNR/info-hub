# Stage 3 rate-construction release manifest

**Integrated release:** 1.0.7  
**Release date:** 26 August 2026  

This manifest binds the exact v1.0.7 payload. Verify SHA-256 checksums before installation.

| Payload | SHA-256 |
|---|---|
| `STAGE3_RATE_CONSTRUCTION_HANDOVER.md` | `7c7ae5d1fe67bf512108eb69f40b321a0b3d442fb191e027b1394b02a1f767f3` |
| `STAGE3_RATE_CONSTRUCTION_RELEASE_REVIEW_v1_0_7.md` | `946559473205b46ed2108b26a293a494a28c658ebb1bc54a5cc230a4ff448f5d` |
| `reference_assets/who_world_standard_2000_2025.dta` | `badde721ca89bab3a85e75fb3e95f2cfcf4a958ff87fab41af71137d65bc9051` |
| `scripts/stata/metrics/cvd/bnr_cvd_construct_incidence_rates_core.do` | `6562257bd6f61dfc422bd6d627ba291b6182fdc27d7a4d31fef0af4f816ac6f9` |
| `scripts/stata/metrics/cvd/bnr_cvd_prepare_rate_reference.do` | `3e5743b69893566393b90a385a0a75c9b386a878f0698c6ceb7ccb3caaa126e5` |
| `scripts/stata/metrics/cvd/bnr_cvd_run_incidence_rate_estimation.do` | `3b02317e64f73ec8ae59a6da2ce2fb4842c6e2a0e77486fda36d8330221a5e7e` |
| `scripts/stata/metrics/cvd/tests/test_bnr_cvd_construct_incidence_rates.do` | `f4370eacf99c08938d98985a066421937d08d35f63e4dca004f06ce9c8f245e0` |
| `scripts/stata/metrics/cvd/tests/test_bnr_cvd_prepare_rate_reference.do` | `3dfec1fcc589eae5a9e9f9336c50edf86e8252cf814631518d9c8af067a17f95` |

The manifest itself is excluded from the checksum table. The package contains only the files listed above plus this manifest.
