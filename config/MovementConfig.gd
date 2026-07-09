class_name MovementConfig
extends Resource
# C1 naval-movement tunables only (docs/specs/naval-movement.md). Instance lives at
# config/movement.tres. Per the config-split rule in `config/SimConfig.gd`, this file stays scoped to
# hull handling and never absorbs unrelated tunables (wake/HUD cosmetics tune in FieldConfig, weapons
# will get their own config). Start values are the owner-approved mockup-gate anchors.

@export var max_speed_ahead: float = 220.0   # full ahead speed, u/s
@export var astern_frac: float = 0.35        # reverse cap as a fraction of ahead
@export var thrust_accel: float = 55.0       # u/s² under full throttle (~4.5s to full)
@export var brake_accel: float = 90.0        # u/s² while the order opposes current keel motion
@export var drag_forward: float = 0.08       # 1/s exponential along-keel drag (long coast)
@export var drag_lateral: float = 1.8        # 1/s lateral drag (slip decays, visibly)
@export var turn_rate_max: float = 0.55      # rad/s at full speed, full rudder
@export var turn_speed_floor: float = 0.25   # min fraction of turn authority at a standstill
