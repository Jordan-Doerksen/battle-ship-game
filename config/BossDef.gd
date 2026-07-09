class_name BossDef
extends Resource
# One rung of the C7 ladder (docs/specs/boss-ladder.md) — a mothership war machine. Lives as a
# sub-resource inside config/bosses.tres — see BossConfig.gd. `parts` entries are
# { "pn": display name, "hp": float, "ox"/"oy": hull-local offset, "r": hit radius, "role":
# gun | director | bay | hive | vent }. Machine-specific fields stay 0/default on the others.

@export var id: String = ""
@export var display_name: String = ""      # THE-designation on the PRIORITY TARGET plate
@export var layer: String = "surf"         # surf | air | sub (the MAW breach-cycles sub↔surface)
@export var core_hp: float = 40.0
@export var radius: float = 30.0           # core hull hit radius
@export var speed: float = 30.0
@export var turn: float = 0.4
@export var standoff: float = 550.0        # approach → orbit, gunboat-pattern brain
@export var parts: Array[Dictionary] = []
# JUGGERNAUT guns
@export var fire_period: float = 0.0
@export var shell_speed: float = 0.0
@export var shell_dmg: int = 0
@export var lead: float = 0.0
@export var spread: float = 0.0
@export var panic_rate: float = 1.0        # rate multiplier once the fire director dies
@export var phase_speed: float = 0.0       # +speed per part lost
@export var phase_spawn: String = ""       # minion type vomited per part lost
@export var phase_spawn_n: int = 0
# CANOPY bays + hive
@export var bay_period: float = 0.0
@export var bomb_speed: float = 0.0
@export var bomb_dmg: int = 0
@export var hive_period: float = 0.0
@export var hive_spawn: String = ""
@export var hive_spawn_n: int = 0
@export var phase_rate: float = 1.0        # remaining periods scale per part lost
@export var hive_death_spawn: String = ""
@export var hive_death_n: int = 0
# MAW torpedoes + breach cycle
@export var torp_fan: int = 0
@export var fan_arc: float = 0.0
@export var torp_speed: float = 0.0
@export var torp_dmg: int = 0
@export var torp_run: float = 0.0
@export var dive_secs: float = 0.0
@export var breach_secs: float = 0.0
@export var breach_ext: float = 0.0        # breach extension per cowl destroyed
