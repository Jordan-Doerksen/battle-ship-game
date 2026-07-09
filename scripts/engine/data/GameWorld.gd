class_name GameWorld
extends RefCounted
# THE WORLD — the single mutable source of truth. Grows one chunk at a time; carries ONLY state a
# landed system reads (DECISIONS Non-Negotiable Constraints: no dead mechanics). C1 added the ship;
# C2 added mounts, pooled shells, kills, and the effects queue; C3 added enemies, the hull pool, and
# the wave-director state (the C2 practice drones retired with their range).
#
# `effects` is the one-way sim→render event stream (muzzle/splash/death/hit). The sim appends;
# Main (app layer) hands the batch to the renderer after stepping and clears it — the renderer
# itself never touches the world beyond reads.
#
# The world holds NO view/window/camera size — the renderer owns the camera + sea-field tile. No sim
# system may ever read screen size.

var world_seed: int = 0
var rng: Rng
var elapsed: float = 0.0
var tick: int = 0
var ship_pos: Vector2 = Vector2.ZERO
var ship_vel: Vector2 = Vector2.ZERO
var ship_heading: float = 0.0            # radians; 0 = north (screen up), positive = clockwise
var input: InputState = InputState.new() # written by Main pre-step; read-only inside the sim
var mounts: Array = []                   # Mount runtime state, index-locked to HardpointConfig
var enemies: Array = []                  # Enemy slots for the current wave (Waves.gd fills/clears)
var projectiles: Pool
var kills: int = 0
var effects: Array = []
var hull: int = -1                       # pips; -1 = uninitialized, Waves.step sets from WaveConfig
var grace_until: float = 0.0             # post-hit invulnerability end time (Hull.gd)
var run_over: bool = false               # hull reached 0 — Main shows the card and restarts
var wave: int = 0
var wave_state: String = "lull"          # lull | fighting
var lull_until: float = -1.0             # -1 = arm from first_wave_delay on the first step
var xp_run: int = 0                      # XP earned this sortie (C4); Main banks it into the Profile
var crash_until: float = -1.0            # CRASH TURN window end (marquee; Movement.gd)
var crash_ready: float = 0.0             # CRASH TURN cooldown gate
var dc_cool: float = 0.0                 # depth-charge rack cooldown (C5; DepthCharges.gd)
var helo_state: String = "pad"           # C6 AIR WING (AirWing.gd): pad | air | rtb
var helo_pos: Vector2 = Vector2(0, 65)   # starts on the stern helipad (ship at origin, heading 0)
var helo_heading: float = 0.0
var helo_fuel: float = 0.0               # airborne seconds remaining
var helo_rearm: float = 0.0              # pad seconds remaining before relaunch
var helo_drop_cool: float = 0.0          # light-rack cooldown
var helo_phase: float = 0.0              # escort-weave phase (gate rev 1)
var helo_gun_cool: float = 0.0           # door-gun cadence (gate rev 2)
var helo_mark: Vector2 = Vector2.ZERO    # last torpedo launch point (valid while elapsed < helo_mark_until)
var helo_mark_until: float = -1.0
var godmode: bool = false                # DEV test kit only (debug builds); guards Hull.damage
var freeze_waves: bool = false           # DEV test kit only (debug builds); pauses the director

func _init(seed_val: int) -> void:
	world_seed = seed_val
	rng = Rng.new(seed_val)
	projectiles = Pool.new(func() -> Projectile: return Projectile.new())
