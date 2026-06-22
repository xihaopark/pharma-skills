# Post-hoc / NONMEM Individual Prediction Overlay

A useful diagnostic layer for individual PK panels is the per-subject model prediction
(NONMEM/post-hoc `IPRED`-style trace) drawn over the observed PK as a subdued dashed line.
It turns each subject facet into an observed-vs-individual-fit panel, so reviewers can eyeball
model misfit, mis-timed doses, or outlier subjects without leaving the individual-review plot.

Build the base individual PK plot object first, then add the prediction as a final
`geom_line()` layer so it sits on the same facets and time origin.

```r
# 1. Read the post-hoc/sdtab table and build an ID that matches the plot's compact facet ID.
#    The model ID is usually a bare integer; map it to the SAME compact ID used in the
#    PK/exposure facets (this join key is the #1 thing people get wrong).
posthoc_ind <- read.table("<path>/sdtab1062", skip = 1, header = TRUE) %>%
  mutate(
    ID  = paste0("S", ID),   # ADC study example; deidentified mock fixture uses
                             #   paste0("mock", sprintf("%03d", as.numeric(ID)))
    AUC = AUC / 1000,        # mirror any conc unit conversion applied to observed data
    CP  = CP                 # individual predicted concentration column (intact ADC here)
  )

# 2. Overlay on the already-built base plot for one cohort.
pk_plot_cohort +
  geom_line(
    data = posthoc_ind %>%
      filter(TIME >= 0, TIME <= 3 * 3 * 7,                 # early window only (study-specific)
             ID %in% subset(dat_ex1, EXDOSP >= 5)$ID),     # restrict to this cohort's subjects
    aes(x = TIME, y = CP / 1000, group = ID),              # CP/1000: ng/mL -> ug/mL to match observed
    color = "grey", linetype = "dashed"
  )
```

## Study-specific knobs to set every time

- **Join key.** `posthoc_ind$ID` must be transformed to equal the compact `ID` on the facets.
  The ADC template uses `paste0("S", ID)`; the deidentified mock fixture uses
  `paste0("mock", sprintf("%03d", as.numeric(ID)))`. A wrong key silently yields an empty
  overlay (no error, just no dashed lines).
- **Cohort subset.** The prediction column is shared across all subjects, so restrict to the
  cohort being plotted — by exact dose (`EXDOSP == 6`) or a dose band (`EXDOSP >= 5`) — matching
  whatever defined `Cohort`.
- **Concentration scaling.** Divide the predicted column to the observed analyte's units
  (here `CP / 1000` for ng/mL -> ug/mL, mirroring the `AUC / 1000` conversion). For payload
  overlays use the payload prediction column (e.g. `CPP`) with its own scaling.
- **Time-axis alignment (verify).** The overlay must share the base layer's time origin and
  transform. The base PK layer typically plots `x = TIME / 168` (weeks); the source snippet
  overlays `aes(x = TIME)` in raw model time, which only lines up when the model `TIME` is
  already on the same scale/window. When in doubt, plot the overlay with the **same** transform
  as the base (`x = TIME / 168` if model `TIME` is in hours) and confirm the dashed trace falls
  under the observed points rather than drifting off to one side.

Keep the overlay optional and guarded: skip it (do not error) when the post-hoc file is absent
or the join produces zero matching rows. Do not invent a new prediction grammar.

## Provenance

Pattern validated against `mock_dataset_01/Script_adapted/ER_mock_analysis.Rmd` (chunk `indi_ADC6`,
`posthoc_ind` + `geom_line(CP/1000)` overlay) — see figure `run2/figure/indi_ADC6-2.png`.
Mirrors the same note in the `.claude` global skill bundle
(`plot-individual-pk-data/references/individual-pk-plot-pattern.md`, "Post-hoc / NONMEM
Individual Prediction Overlay"). This repo bundle does not ship `plot-individual-pk-data`
(deliberately removed), so Core 2 keeps the recipe self-contained here.
