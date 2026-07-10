class_name CameraConfig
extends Resource
# C10 TACTICAL ZOOM tables (app/render side ONLY — the sim never reads camera state; GameWorld's
# law stands). Owner-approved at the mockup gate 2026-07-09 (design/tactical-zoom.html, defaults
# shipped as judged). The C1 hardcoded 0.85 in Main.tscn died with this file. Per the config-split
# rule this stays scoped to the camera; render cosmetics live in FieldConfig.

@export var zoom_min: float = 0.40         # farthest out — the C10 floor the C9 art was proven at
@export var zoom_max: float = 0.85         # closest in — the LOOK-LOCKED C2 view
@export var zoom_home: float = 0.51        # sortie-start + H-key snap — the owner's judged view
@export var wheel_step: float = 1.18       # multiplicative zoom per wheel notch
@export var lerp_half_life: float = 0.12   # seconds to close half the gap to the target zoom
@export var enemy_min_px: float = 10.0     # smallest hostiles never render under this apparent size
@export var stroke_comp: bool = true       # outline widths hold their 0.85-baseline apparent weight
