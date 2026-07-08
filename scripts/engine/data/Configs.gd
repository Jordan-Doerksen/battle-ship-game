class_name Configs
extends RefCounted
# The bundle of per-system config handles that Sim.step threads to its systems. Each domain STILL
# lives in its own small .tres (the config-split rule in config/SimConfig.gd) — this class is only
# the carrier, so Sim.step's signature doesn't grow a parameter per chunk. `gunnery` is the practice
# range (RangeConfig); named to avoid shadowing GDScript's range().

var movement: MovementConfig
var hardpoints: HardpointConfig
var weapons: WeaponConfig
var waves: WaveConfig
var enemies: EnemyConfig

# Class-default values (which mirror every .tres) — probes use this so they run without the
# resource files; Main uses load_all() for the real tunables.
static func defaults() -> Configs:
	var c := Configs.new()
	c.movement = MovementConfig.new()
	c.hardpoints = HardpointConfig.new()
	c.weapons = WeaponConfig.spec_defaults()
	c.waves = WaveConfig.new()
	c.enemies = EnemyConfig.spec_defaults()
	return c

static func load_all() -> Configs:
	var c := defaults()
	var m := load("res://config/movement.tres") as MovementConfig
	if m != null: c.movement = m
	var h := load("res://config/hardpoint.tres") as HardpointConfig
	if h != null: c.hardpoints = h
	var w := load("res://config/weapons.tres") as WeaponConfig
	if w != null and w.catalog.size() > 0: c.weapons = w
	var wv := load("res://config/waves.tres") as WaveConfig
	if wv != null: c.waves = wv
	var en := load("res://config/enemies.tres") as EnemyConfig
	if en != null and en.roster.size() > 0: c.enemies = en
	return c
