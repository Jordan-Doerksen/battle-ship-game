class_name FieldConfig
extends Resource
# Cosmetic sea-field + wake tunables only (render-side — see FieldRenderer.gd; C1 replaced the C0
# starfield with the mockup-approved ocean: chart grid, drifting foam flecks, wake trail). Instance
# lives at config/field.tres. Per the config-split rule in `config/SimConfig.gd`, this stays scoped to
# the render-side field and never absorbs unrelated tunables (hull handling is MovementConfig).

@export var fleck_count: int = 110         # drifting foam flecks per tile
@export var fleck_min_len: float = 3.0     # px, shortest fleck dash
@export var fleck_max_len: float = 12.0    # px, longest fleck dash
@export var field_tile: float = 1600.0     # toroidal fleck tile size, world units
@export var grid_minor: float = 200.0      # chart-grid minor line spacing, world units
@export var grid_major: float = 1000.0     # chart-grid major line spacing, world units
@export var wake_life: float = 4.5         # seconds a wake puff lives
@export var wake_max_points: int = 700     # wake ring-buffer cap
