class_name TechConfig
extends Resource
# The C4 tech tree (docs/specs/tech-tree.md): the node catalog plus the marquee effects' parameters
# and their runtime FLAGS. Flags default OFF — a zero-tech run is byte-identical to C3 (baseline
# invariance, probe-gated). Tech.apply flips flags/values on a DUPLICATED Configs, never this one.
# Instance lives at config/tech.tres (generated from spec_defaults(), which is the source mirror).

@export var catalog: Array[TechDef] = []

# marquee parameters (tunables) + flags (flipped by marquee nodes via mods paths "tech.<flag>")
@export var crash_turn: bool = false
@export var crash_mult: float = 1.8
@export var crash_secs: float = 3.0
@export var crash_cooldown: float = 13.0   # from trigger: 3s window + 10s rest
@export var crash_min_frac: float = 0.7    # min fraction of full ahead to arm
@export var incendiary: bool = false
@export var burn_ticks: int = 3
@export var burn_dmg: int = 1
@export var airburst: bool = false
@export var airburst_trigger: float = 8.0
@export var airburst_radius: float = 20.0
@export var salvo: bool = false
@export var salvo_offset: float = 0.015

func by_id(nid: String) -> TechDef:
	for n in catalog:
		if n.id == nid:
			return n
	return null

static func _node(id: String, br: String, nm: String, ds: String, cost: int, mods: Array, marquee := false, locked := false) -> TechDef:
	var n := TechDef.new()
	n.id = id; n.branch = br; n.display_name = nm; n.desc = ds; n.cost = cost
	n.marquee = marquee; n.locked = locked
	var typed: Array[Dictionary] = []
	for m in mods:
		typed.append(m)
	n.mods = typed
	return n

# The spec-table tree — MUST mirror config/tech.tres exactly (the .tres is generated from this).
static func spec_defaults() -> TechConfig:
	var c := TechConfig.new()
	var cat: Array[TechDef] = [
		_node("sea1", "SEAMANSHIP", "Trim Ballast", "+10% max speed", 1, [{ "p": "move.max_speed_ahead", "mul": 1.10 }]),
		_node("sea2", "SEAMANSHIP", "Keel Shave", "+15% turn rate", 1, [{ "p": "move.turn_rate_max", "mul": 1.15 }]),
		_node("sea3", "SEAMANSHIP", "Engine Overhaul", "+20% thrust", 1, [{ "p": "move.thrust_accel", "mul": 1.20 }]),
		_node("sea4", "SEAMANSHIP", "Hard Rudder", "turn floor 0.25→0.40", 2, [{ "p": "move.turn_speed_floor", "set": 0.40 }]),
		_node("sea5", "SEAMANSHIP", "Sea Legs", "+2 hull pips", 2, [{ "p": "waves.hull_pips", "add": 2 }]),
		_node("sea6", "SEAMANSHIP", "CRASH TURN", "EMERGENCY BACK at speed: ×1.8 turn, 3s (cd 10s)", 3, [{ "p": "tech.crash_turn", "set": true }], true),
		_node("flk1", "FLAK", "Gun Oil", "+15% AA fire rate", 1, [{ "p": "weapons.aa20.rate", "mul": 1.15 }]),
		_node("flk2", "FLAK", "Tight Chokes", "−25% AA spread", 1, [{ "p": "weapons.aa20.spread", "mul": 0.75 }]),
		_node("flk3", "FLAK", "Rapid Traverse", "+25% S traverse", 1, [{ "p": "weapons.aa20.traverse", "mul": 1.25 }]),
		_node("flk4", "FLAK", "Cooling Jackets", "−40% bloom gain", 2, [{ "p": "weapons.aa20.bloom_add", "mul": 0.60 }]),
		_node("flk5", "FLAK", "Extended Belts", "+15% AA range", 2, [{ "p": "weapons.aa20.range_u", "mul": 1.15 }]),
		_node("flk6", "FLAK", "INCENDIARY LOAD", "AA hits ignite air targets: 3 dmg over 3s", 3, [{ "p": "tech.incendiary", "set": true }], true),
		_node("gun1", "GUNNERY", "Calibrated Sights", "−30% 5-in spread", 1, [{ "p": "weapons.dp5.spread", "mul": 0.70 }]),
		_node("gun2", "GUNNERY", "Power Rammer", "+25% 5-in fire rate", 1, [{ "p": "weapons.dp5.rate", "mul": 1.25 }]),
		_node("gun3", "GUNNERY", "Fast Slew", "+25% M traverse", 1, [{ "p": "weapons.dp5.traverse", "mul": 1.25 }]),
		_node("gun4", "GUNNERY", "Long Barrels", "+15% range & shell speed", 2, [{ "p": "weapons.dp5.range_u", "mul": 1.15 }, { "p": "weapons.dp5.speed", "mul": 1.15 }]),
		_node("gun5", "GUNNERY", "Heavy Shells", "+1 5-in damage", 2, [{ "p": "weapons.dp5.dmg", "add": 1 }]),
		_node("gun6", "GUNNERY", "PROXIMITY BURST", "5-in shells airburst: 20u flak cloud vs air", 3, [{ "p": "tech.airburst", "set": true }], true),
		_node("ord1", "ORDNANCE", "Turret Gearing", "+30% L traverse", 1, [{ "p": "weapons.mb16.traverse", "mul": 1.30 }]),
		_node("ord2", "ORDNANCE", "Bigger Charges", "+15% 16-in range", 1, [{ "p": "weapons.mb16.range_u", "mul": 1.15 }]),
		_node("ord3", "ORDNANCE", "Wide Bursting", "+25% splash radius", 2, [{ "p": "weapons.mb16.splash", "mul": 1.25 }]),
		_node("ord4", "ORDNANCE", "Fire Control", "−50% 16-in spread", 2, [{ "p": "weapons.mb16.spread", "mul": 0.50 }]),
		_node("ord5", "ORDNANCE", "Fast Reload", "+30% 16-in fire rate", 2, [{ "p": "weapons.mb16.rate", "mul": 1.30 }]),
		_node("ord6", "ORDNANCE", "FULL SALVO", "both barrels: 2 shells per trigger", 3, [{ "p": "tech.salvo", "set": true }], true),
		_node("air1", "AIR WING", "████████", "PENDING BUREAU AUTHORIZATION", 0, [], false, true),
		_node("air2", "AIR WING", "██████", "████ ████████ ████", 0, [], false, true),
		_node("air3", "AIR WING", "█████████", "REDACTED — EXECUTIVE ORDER", 0, [], false, true),
		_node("air4", "AIR WING", "███████", "████████", 0, [], false, true),
		_node("air5", "AIR WING", "████ ████", "CLEARANCE INSUFFICIENT", 0, [], false, true),
	]
	c.catalog = cat
	return c
