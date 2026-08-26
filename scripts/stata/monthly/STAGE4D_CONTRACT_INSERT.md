## Approved unresolved-link estimator hierarchy (Stage 4D)

For the initial annual national All-CVD DCO series, use a sexes-combined annual
estimation stratum separately for each mortality definition (`primary` and
`inclusive`). Let `L` be deterministic recorded 0–27-day episode links, `A`
deterministic additional DCOs and `U` unresolved candidates.

1. Use the target calendar year's \(p=A/(L+A)\) when \(L+A\ge20\).
2. If the annual resolved count is below 20, pool actual available candidate
   records in the target year plus/minus one calendar year, within the same
   mortality definition, and use that \(p\) when its resolved count is at
   least 20.
3. If that pool remains below 20, use all available candidate years within the
   same mortality definition when its resolved count is at least 20.
4. Otherwise record `insufficient_resolved` and do not calculate a central
   estimate for that annual cell.

Apply \(\widehat{U}_{DCO}=pU\) only to the aggregate annual cell. Do not label
or allocate an estimated DCO to an unresolved individual. Retain the selected
level, source-year range, resolved denominator and fraction privately.
