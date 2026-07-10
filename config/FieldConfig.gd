class_name FieldConfig
extends Resource
# Cosmetic sea-field + wake tunables only (render-side — see FieldRenderer.gd; C1 replaced the C0
# starfield with the mockup-approved ocean: chart grid, drifting foam flecks, wake trail; C9 taught
# the water to move — design/living-sea.html direction B "HEAVY WEATHER" is the approved reference,
# these defaults ARE that preset + the owner's gate tunes). Instance lives at config/field.tres.
# Per the config-split rule in `config/SimConfig.gd`, this stays scoped to the render-side field
# and never absorbs unrelated tunables (hull handling is MovementConfig).

@export var fleck_count: int = 210         # drifting foam flecks per tile (C9: B preset density)
@export var fleck_min_len: float = 3.0     # px, shortest fleck dash
@export var fleck_max_len: float = 12.0    # px, longest fleck dash
@export var field_tile: float = 1600.0     # toroidal fleck tile size, world units
@export var grid_minor: float = 200.0      # chart-grid minor line spacing, world units
@export var grid_major: float = 1000.0     # chart-grid major line spacing, world units
@export var wake_life: float = 9.0         # seconds a wake puff lives (C9 gate tune)
@export var wake_max_points: int = 900     # wake ring-buffer cap
@export var wake_width: float = 1.35       # wake puff radius multiplier

# ── C9 THE LIVING SEA (all render-only; sim never reads any of these) ──────────────────────────
@export var sea_amp: float = 0.95          # swell band strength (shader alpha multiplier)
@export var sea_drift: float = 1.4         # swell drift speed multiplier
@export var sea_scale: float = 1.15        # swell band spatial scale multiplier
@export var glint_intensity: float = 0.75  # sun-glint field strength (0 = the old dead sea)
@export var crest_bias: float = 0.85       # how hard flecks cling to analytic-swell crests
@export var crest_streaks: float = 0.8     # breaking crest-foam streak intensity (0 = off)
@export var heave_px: float = 3.0          # ship render bob amplitude, world units (≈px at 1x)
@export var roll_deg: float = 2.6          # ship render roll amplitude, degrees
@export var shadow_px: float = 5.0         # hull shadow offset (breathes with the heave)
@export var splash_scale: float = 1.4      # shell splash column scale (owner gate tune)
@export var splash_foam_life: float = 3.4  # lingering splash foam-disc life, seconds (gate tune)
@export var splash_dye: bool = true        # per-battery splash rim tint (WWII spotting practice)
@export var reduced_motion: bool = false   # LAW: freezes sea/ride/column anim; foam discs stay
