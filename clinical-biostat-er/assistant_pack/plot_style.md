# ER Plot Style Guide

> ER plotting standard. The executable source of truth is
> `assistant_pack/theme_er.R` (`theme_er()`, `er_semantic_colors`,
> `er_event_shapes`, figure sizes); Core 2's plotting corpus mirrors it.
> This is an ER-native support asset for the `clinical-biostat-er` bundle.

## 1. Role in the Skill Bundle

This file defines plotting conventions for Claude Code to apply while executing
the six ER core skills. It is not a standalone external plotting skill, and it
does not create analysis methodology. Core 1 records study-specific mappings in
`config/er_workflow_spec.yaml`; Cores 2-5 use this style contract when they
generate review figures and diagnostics.

## 2. Official AZ Color Packages (authoritative source)

The canonical AZ brand color palettes are maintained in two official packages — one per language. Use these instead of hardcoded hex values.

### 2.1 azcolors (R — ggplot2 integration)

- **Repo**: `azu-biopharmaceuticals-rd/azcolors`
- **Install**: `install.packages("azcolors", repos = "https://azu-biopharmaceuticals-rd.github.io/azcolors")`

**12 base brand colors** (accessible via `azcolors::az_colors`):

| Name | Hex | Name | Hex |
|---|---|---|---|
| `mulberry` | `#830051` | `purple` | `#3c1053` |
| `dark_mulberry` | `#4d0030` | `navy` | `#003865` |
| `magenta` | `#d0006f` | `light_blue` | `#68d2df` |
| `graphite` | `#3f4444` | `lime_green` | `#c4d600` |
| `platinum` | `#9db0ac` | `gold` | `#f0ab00` |
| `light_platinum` | `#ebefee` | `white` | `#ffffff` |

**Named palettes** (pass to `az_palette()` or `scale_*_azcolors()`):

| Palette | Colors included | Type |
|---|---|---|
| `core` | mulberry, dark_mulberry, magenta, graphite, platinum, gold | fixed |
| `secondary` | light_platinum, purple, navy, light_blue, lime_green | fixed |
| `illuminating` | magenta, gold, light_blue, lime_green | fixed |
| `neutrals` | graphite, platinum, light_platinum, white | fixed |
| `main` | core + secondary (9 colors, spline-interpolated in Lab space) | interpolated |

**Key ggplot2 functions**:

```r
library(azcolors)

# discrete fill / color scale
scale_fill_azcolors(palette = "core", discrete = TRUE)
scale_color_azcolors(palette = "main", discrete = TRUE)

# continuous fill scale
scale_fill_azcolors(palette = "mulberry", discrete = FALSE, reverse = TRUE)

# programmatic palette vector
az_palette("core", n = 6, discrete = TRUE)
az_palette("navy",  n = 9, discrete = FALSE, spread_max = 0.8, spread_min = 0.2)

# preview a palette
preview_palette("illuminating")
```

### 2.2 azchroma (Python — matplotlib / seaborn)

- **Repo**: `azu-biopharmaceuticals-rd/azchroma`
- **Install**: `pip install azchroma`

Same 12 base colors and 5 named palettes as `azcolors` (shared YAML config).

**Key functions**:

```python
from azchroma import az_palette, az_cmap, az_colors

# list of hex colors
az_palette("core", n=6, discrete=True)
az_palette("mulberry", n=9, discrete=False, reverse=True)

# matplotlib colormap (continuous → LinearSegmentedColormap)
cmap = az_cmap("core")

# matplotlib colormap (discrete → ListedColormap)
cmap = az_cmap("core", n=6)

# individual color lookup
az_colors["mulberry"]   # → "#830051"
az_colors["navy"]       # → "#003865"

# with matplotlib
import matplotlib.pyplot as plt
plt.scatter(x, y, c=values, cmap=az_cmap("lime_green"))

# with seaborn
import seaborn as sns
sns.color_palette(az_palette("main", n=8, discrete=True))
```

### 2.3 Relationship to theme_er.R fallback

`assistant_pack/theme_er.R` defines:
- `az_colors_canonical` — the full 12-color named vector (mirrors `azcolors::az_colors`), usable without installing the package
- `az_palette` — a 5-color legacy fallback subset for `theme_er()` internal use
- `theme_er()`, `er_scale_x_log10()`, `er_ribbon_ci()`, `er_caption()` — ER-specific theme utilities

**Priority rule**: when `azcolors` is available, use `scale_fill_azcolors()` / `scale_color_azcolors()` directly; use `az_palette` from `theme_er.R` only in environments where `azcolors` is not installed.

## 3. Theme rules

- **Theme**: always `theme_er()` (`assistant_pack/theme_er.R`). It is `theme_bw()`-based so dense faceted plots keep clear panel borders; plotting code must not use raw `theme_gray()` / `theme_bw()` as the default.
- **Font**: parameterize `base_size`; never hardcode `size = 10`.
- **Color**: prefer `azcolors::scale_fill_azcolors()` / `scale_color_azcolors()` (§2.1); without azcolors, use the `theme_er.R` `az_palette` fallback. Primary mulberry `#830051` / navy `#003865` / accent `#C4262E`.
- **Axes**: default `er_scale_x_log10()` on the exposure axis; response axis per data range.
- **CI bands**: every model-fit line carries an `er_ribbon_ci()` 95% CI.

### 3.1 Event markers (shape + color standard)

Individual PK/PD/CK event markers use the canonical glyphs in
`theme_er.R::er_event_shapes` — the shape itself carries meaning, so render on a
Unicode-capable PNG device (Quartz/Cairo; a non-Cairo bitmap device blanks them):

- Response = `★` (U+2605); any AE / AESI / ILD = `◎` (U+25CE), with **color**
  separating the family members; dose / infusion = `↑` (U+2191), with color
  encoding dose level.

Marker colors come from `theme_er.R::er_semantic_colors` and must clear the WCAG
3:1 graphic-object floor on the white/light-strip panels: `response_marker`
mulberry `#830051`, `grade3_ae` red `#C4262E`, `adjudicated_safety` navy
`#003865`, `non_adjudicated_safety` graphite `#3f4444`. The light AZ accents
(lime green, gold) fail 3:1 as discrete markers and are reserved for fills/series —
do not use them for event glyphs, and do not reuse `exposure_point` gold for a marker.

## 4. Manifest / anti-copy-paste gate

Each figure's `plot.caption` should carry provenance:
```
study=<study_id> | run=<run_id> | src=<source_file>
```
generated by `assistant_pack/theme_er.R::er_caption()`. Rationale: a reused figure
that silently keeps a prior run's caption is untraceable; a caption-less figure is
of unknown origin and a reviewer should reject it. Figure provenance is also
recorded in `outputs/manifest.json` and the per-core plot manifests.

## 5. Figure sizes

Pull sizes from `theme_er.R::er_get_figure_size(kind)` rather than hardcoding:

| Use | W × H (inch) | DPI | `kind` |
|---|---|---|---|
| Exploratory / individual-profile review | 16 × 9 | 300 | `exploratory_review` / `individual_profile` |
| TLF body figure | 6.5 × 4.0 | 300 | `tlf_body` |
| Appendix detail | 8.5 × 6.0 | 300 | `appendix_detail` |
| Internal slide | 10 × 5.625 (16:9) | 150 | `internal_slide` |

Pass explicitly to `ggsave(..., width = W, height = H, dpi = D)`; do not rely on
device defaults. (Faceted Core 2 figures size from their grid shape via
`core2_facet_figure_size()`.)

## 5.1 Reusable ER chart defaults distilled from sample contracts

The sample ADC oncology contract contains reusable chart grammar, but its product names, endpoint labels, dose mappings, posthoc file names, and exposure derivation variables are fixture configuration only. General ER skills should reuse the conventions below and replace study-specific variables from the current workflow spec.

### 5.1.1 Exploratory ER combined figure

When plotting-ready subject-level exposure and endpoint data support it, default to a 3-panel exploratory review layout:

1. **Endpoint/event group exposure distribution**: boxplot or violin/box hybrid of the selected exposure by endpoint/event status, with subject-level jitter overlaid.
2. **Endpoint-vs-exposure relationship**: model or smoother overlay appropriate to endpoint scale; for binary endpoints, use logistic fit, subject jitter, 95% CI ribbon, and binned or quartile observed-rate points with intervals when sample size supports them.
3. **Dose/group exposure distribution**: boxplot or equivalent distribution view by dose, cohort, or treatment group.

Default composition is 16:9 at 300 dpi for exploratory review figures. Use the study/output shell when it explicitly provides another size. Use `theme_er()` to implement the white-background, simple-axis convention; `theme_er()` is `theme_bw()`-based for complex panels, but plotting code should not bypass it with raw `theme_bw()` defaults.

### 5.1.2 Individual PK/PD/CK review figure

Individual profile figures default to a swimmer-aligned subject-facet grammar:

- derive all PK/PD/CK curves, dosing intervals, response/safety events, and optional model overlays on a shared time origin, normally time since first relevant dose or intervention;
- facet by masked subject ID and avoid full subject identifiers in labels or filenames unless explicitly permitted;
- order subject facets by clinically meaningful response/status blocks when available, then by stable first appearance in the analysis dataset;
- show observed PK/PD/CK values as points plus connecting lines, treatment intervals as lower-band segments, study drug administrations as dose markers, response markers as distinct positive-outcome symbols, safety markers as event symbols, and optional model/posthoc predictions as subdued dashed overlays;
- compute marker bands dynamically from the plotted y-range; for high dynamic range CAR-T/CK data, compute BLQ flooring, marker bands, and y-limits on the log10 scale.

Default legend placement is bottom, with grouped legend order `Treatment`, `Events`, then `Dose/Group` when those components are present.

### 5.1.3 Generalization boundary

Use the chart grammar above as defaults. Do not turn fixture terms such as `CompoundX`, `AUC1`, `sdtab1062`, fixed treatment mappings, fixed nominal visits, fixed AESI lists, or sample endpoint labels into defaults. Store those as study configuration, fixture examples, or explicit business rules for the current analysis.

## 6. Naming convention

Figures write under the study's per-core outputs directory with a descriptive,
slugged filename:

```
outputs/<core_step>/<figure_slug>.png
e.g. outputs/02_individual_pk_pd_review/pooled_PK_<sanitized_PARAMREP>.png
     outputs/05_statistical_modeling/LOGI_<model_id>.png
```

Filenames are recorded in the per-core plot manifest + `outputs/manifest.json`.
Forbidden: non-English filenames, spaces, or filenames that leak a raw
treatment-arm code where a nominal-dose label is available.

## 7. Disallowed

- `ggplotly()` (non-interactive deliverables).
- Externally-linked fonts (offline regulatory environments).
- The default ggplot2 theme (replaced by `theme_er()`).

## 8. Related

- `azcolors` (R pkg) — canonical AZ ggplot2 color scales (`azu-biopharmaceuticals-rd/azcolors`).
- `azchroma` (Python pkg) — canonical AZ matplotlib/seaborn color maps (`azu-biopharmaceuticals-rd/azchroma`).
