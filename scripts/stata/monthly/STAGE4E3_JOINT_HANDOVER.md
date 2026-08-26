# CVD workflow hardening — Stage 4E-c joint subtype estimator

This replaces the proportional Stage 4E-c reconciliation pass. All-CVD Stage
4D is the unresolved-DCO anchor. Stage 4E-a routes are converted into three
mutually exclusive categories: Heart, Stroke and mixed/unallocated.

For each mortality definition and year, the observed deterministic additional
DCO composition supplies allocation probabilities. The selected composition
uses annual resolved evidence when the total resolved count is at least 20,
then the same-definition year +/-1 pool, then all available years. The
All-CVD unresolved central component is allocated using those probabilities.

The public accounting identity is therefore structural:

```text
All-CVD = Heart + Stroke + mixed/unallocated
```

The mixed category is a genuine joint allocation category, not a negative or
post-hoc residual. The independent Stage 4E-b subtype estimates remain useful
private sensitivity diagnostics but are not the production source.

## Install and test

Copy the three DO files under their paths in the repository. Run:

```stata
do "$BNR_STATA/metrics/cvd/tests/test_bnr_cvd_stage4_joint_subtype_estimation.do"
```

Then run the private estimator in one CLI line:

```stata
do "$BNR_STATA/metrics/cvd/bnr_cvd_run_joint_subtype_estimation.do" 2024 04 2026 07 replace
```

Review the QA CSV and private log before rate construction. No public output
is created by this pass.
