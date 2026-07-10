class_name TerrainConfig
extends Resource
# C15 THE WATERS (design/the-waters.html mockup gate; the land rules live in DECISIONS.md's
# Change Log, 2026-07-10). Instance lives at config/terrain.tres. Per the config-split rule in
# config/SimConfig.gd this holds generation + grounding + avoidance tunables ONLY — WHO the land
# blocks is law (Projectiles.gd's flies/blocked split), never a knob.

@export var islet_min: int = 3             # owner gate tune 2026-07-10: fixed at 3 (kept as a range so variance can return later)
@export var islet_max: int = 3             # owner gate tune 2026-07-10
@export var rock_min: int = 9              # owner gate tune 2026-07-10: fixed at 9 (same reasoning)
@export var rock_max: int = 9              # owner gate tune 2026-07-10
@export var islet_r_min: float = 60.0      # islet SIM collision radius range, u (base — size_scale rides on top)
@export var islet_r_max: float = 140.0
@export var rock_r_min: float = 10.0       # rock/reef collision radius range, u
@export var rock_r_max: float = 30.0
@export var size_scale: float = 1.35       # owner gate tune 2026-07-10: ×1.35 multiplier on every feature radius at generation
@export var field_extent: float = 1500.0   # features scatter within ±extent of the world origin
@export var start_clear: float = 250.0     # no feature EDGE inside this radius of the ship's start (the origin)
@export var gap_min: float = 180.0         # min edge-to-edge gap between features — the navigable channel
@export var grind_speed_frac: float = 0.45 # fraction of max_speed_ahead: contact whose normal speed exceeds it costs a pip
@export var grind_bleed: float = 0.65      # fraction of slide speed RETAINED PER SECOND while grinding the coast
@export var avoid_look: float = 200.0      # waterborne AI: forward lookahead for tangent avoidance, u
@export var avoid_clear: float = 20.0      # waterborne AI: clearance margin beyond the agent's own radius, u
