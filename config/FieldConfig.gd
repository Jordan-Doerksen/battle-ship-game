class_name FieldConfig
extends Resource
# Cosmetic starfield tunables only (C0 placeholder harness — see FieldRenderer.gd). Instance lives at
# config/field.tres. Per the config-split rule in `config/SimConfig.gd`, this stays scoped to the
# render-side starfield and never absorbs unrelated tunables.

@export var star_count: int = 160
@export var star_min_size: float = 1.0
@export var star_max_size: float = 2.5
@export var field_tile: float = 1800.0
