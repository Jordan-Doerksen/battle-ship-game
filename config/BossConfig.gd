class_name BossConfig
extends Resource
# The C7 boss ladder (docs/specs/boss-ladder.md): cadence, rewards, lap scaling, and the three
# war-machine defs in rung order. Instance lives at config/bosses.tres. Per the config-split rule
# this holds ladder tunables ONLY; the escort wave is the normal director at escort_frac budget.

@export var every_n: int = 5               # a machine every Nth wave
@export var escort_frac: float = 0.5       # the boss wave's normal-director budget fraction
@export var lap_hp_mult: float = 1.5       # core/part hp multiplier per completed ladder lap
@export var xp_part: int = 60              # banked on the spot per destroyed part
@export var xp_core: int = 250             # × lap number on the core kill
@export var hull_patch: int = 2            # pips restored on the kill (capped at hull max)
@export var defs: Array[BossDef] = []

static func _part(pn: String, hp: float, ox: float, oy: float, r: float, role: String) -> Dictionary:
	return { "pn": pn, "hp": hp, "ox": ox, "oy": oy, "r": r, "role": role }

# Spec-table ladder, for probe/boot fallback — values must mirror config/bosses.tres exactly.
static func spec_defaults() -> BossConfig:
	var c := BossConfig.new()
	var jug := BossDef.new()
	jug.id = "juggernaut"; jug.display_name = "THE JUGGERNAUT"; jug.layer = "surf"
	jug.core_hp = 40.0; jug.radius = 30.0; jug.speed = 30.0; jug.turn = 0.4; jug.standoff = 550.0
	jug.parts = [
		_part("FORE TURRET", 10.0, 0.0, -34.0, 12.0, "gun"),
		_part("AFT TURRET", 10.0, 0.0, 34.0, 12.0, "gun"),
		_part("FIRE DIRECTOR", 8.0, 0.0, 0.0, 9.0, "director"),
	]
	jug.fire_period = 3.0; jug.shell_speed = 170.0; jug.shell_dmg = 1
	jug.lead = 0.7; jug.spread = 0.04; jug.panic_rate = 1.3
	jug.phase_speed = 10.0; jug.phase_spawn = "swarmer"; jug.phase_spawn_n = 2
	var can := BossDef.new()
	can.id = "canopy"; can.display_name = "THE CANOPY"; can.layer = "air"
	can.core_hp = 50.0; can.radius = 34.0; can.speed = 55.0; can.turn = 0.5; can.standoff = 480.0
	can.parts = [
		_part("PORT BAY", 9.0, -30.0, 0.0, 11.0, "bay"),
		_part("STBD BAY", 9.0, 30.0, 0.0, 11.0, "bay"),
		_part("DRONE HIVE", 10.0, 0.0, 16.0, 10.0, "hive"),
	]
	can.bay_period = 5.0; can.bomb_speed = 120.0; can.bomb_dmg = 2
	can.lead = 0.5; can.spread = 0.06
	can.hive_period = 5.0; can.hive_spawn = "swarmer"; can.hive_spawn_n = 3
	can.phase_rate = 0.75; can.hive_death_spawn = "bomber"; can.hive_death_n = 2
	var maw := BossDef.new()
	maw.id = "maw"; maw.display_name = "THE MAW"; maw.layer = "sub"
	maw.core_hp = 45.0; maw.radius = 36.0; maw.speed = 45.0; maw.turn = 0.5; maw.standoff = 500.0
	maw.parts = [
		_part("VENT COWL A", 8.0, -18.0, -22.0, 9.0, "vent"),
		_part("VENT COWL B", 8.0, 18.0, -22.0, 9.0, "vent"),
		_part("VENT COWL C", 8.0, 0.0, 28.0, 9.0, "vent"),
	]
	maw.fire_period = 9.0; maw.torp_fan = 3; maw.fan_arc = 0.5
	maw.torp_speed = 130.0; maw.torp_dmg = 2; maw.torp_run = 900.0
	maw.lead = 0.5; maw.spread = 0.04
	maw.dive_secs = 20.0; maw.breach_secs = 8.0; maw.breach_ext = 2.0
	c.defs = [jug, can, maw]
	return c
