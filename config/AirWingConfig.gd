class_name AirWingConfig
extends Resource
# C6 AIR WING helicopter (docs/specs/air-wing.md). Instance lives at config/airwing.tres. Per the
# config-split rule this holds the bird's flight/sensor/armament tunables ONLY; its unlock and
# marquee flags are TechConfig (tech.helo / tech.mad_gear), and the underwater blast physics reuse
# SonarConfig.dc_blast/dc_fuse — one truth. The AIR WING tree branch mods paths "airwing.<field>".

@export var speed: float = 160.0            # base top speed, u/s — effective top = max(speed, ship speed + speed_margin)
@export var turn: float = 2.6               # steering cap, rad/s
@export var speed_margin: float = 80.0      # how much faster than the ship the bird can always fly (gate rev 1)
@export var picket_dist: float = 360.0      # weave station distance ahead of the ship's course
@export var weave_amp: float = 240.0        # S-weave half-width across the bow (gate rev 1)
@export var weave_rate: float = 0.55        # weave phase speed, rad/s (gate rev 1)
@export var dip_radius: float = 240.0       # passive detection radius around the bird
@export var drop_range: float = 70.0        # must be nearly overhead a DETECTED sub to drop
@export var dc_count: int = 2               # light charges per drop
@export var dc_scatter: float = 40.0        # drop scatter around the CONTACT (tighter than the ship's racks)
@export var dc_dmg: int = 1                 # per blast — softens, the stern racks finish (detector-first)
@export var dc_cooldown: float = 9.0        # seconds between drops
@export var patrol_secs: float = 45.0       # airborne endurance
@export var turnaround_secs: float = 10.0   # pad rearm time
@export var investigate_hold: float = 6.0   # how long a torpedo launch point stays worth visiting
@export var gunners: int = 0                # door gunners aboard — DOOR GUNNER nodes add 1 each (gate rev 2)
@export var gun_range: float = 260.0        # door-gun engagement range around the bird
@export var gun_rate: float = 3.0           # rounds/s per gunner (shared trigger cadence)
@export var gun_dmg: int = 1                # per round — chip damage, never a battery
@export var gun_spread: float = 0.14        # rad — wild by design, no target lead
@export var gun_speed: float = 520.0        # tracer speed; each round's reach rolls 40–100% of gun_range
