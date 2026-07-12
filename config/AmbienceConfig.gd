class_name AmbienceConfig
extends Resource
# C19 THE DETAIL PASS (docs/specs/detail-pass.md) — the "one more 1%" layer's dials. One config per
# system (repo law); instance at config/ambience.tres. ENTIRELY render-side: nothing here may ever
# be read by the sim. The readability law rides the alpha ceilings below — the detail layer must
# never out-contrast gameplay marks (torpedo wakes, telegraphs, blips always win).

@export var enabled: bool = true

# ── pack 1: ship liveliness ──
@export var smoke_alpha: float = 0.11      # funnel smoke (throttle-scaled, streams downwind)
@export var smoke_life: float = 2.6
@export var casing_life: float = 1.2       # ejected brass off the M mounts
@export var lamp_period: float = 11.0      # bridge Aldis triplets, mean seconds between sends
@export var spray_speed_frac: float = 0.55 # bow spray arms above this speed fraction (weather-gated)
@export var heel_rudder: float = 0.7       # heel spray arms above this |rudder| at speed

# ── pack 2: battle aftermath ──
@export var slick_life: float = 75.0       # oil slick + debris where a surface enemy sank
@export var slick_alpha: float = 0.45
@export var haze_alpha: float = 0.08       # cordite haze per puff (pool-capped)
@export var haze_life: float = 2.8
@export var bubble_life: float = 2.5       # sub-death boil

# ── pack 3: ambient world ──
@export var gull_count: int = 2
@export var gull_scatter_r: float = 200.0  # gunfire inside this radius scatters the pair
@export var gull_calm_secs: float = 15.0   # how long after the last shot they come back
@export var flotsam_count: int = 10
@export var buoy_count: int = 2            # channel markers seeded off the islets
@export var cloud_alpha: float = 0.05      # drifting cloud-shadow patches
@export var cloud_count: int = 3
