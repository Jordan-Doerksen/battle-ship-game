class_name Configs
extends RefCounted
# The bundle of per-system config handles that Sim.step threads to its systems. Each domain STILL
# lives in its own small .tres (the config-split rule in config/SimConfig.gd) — this class is only
# the carrier, so Sim.step's signature doesn't grow a parameter per chunk. `gunnery` is the practice
# range (RangeConfig); named to avoid shadowing GDScript's range().

var movement: MovementConfig
var hardpoints: HardpointConfig
var weapons: WeaponConfig
var gunnery: RangeConfig

# Class-default values (which mirror every .tres) — probes use this so they run without the
# resource files; Main uses load_all() for the real tunables.
static func defaults() -> Configs:
	var c := Configs.new()
	c.movement = MovementConfig.new()
	c.hardpoints = HardpointConfig.new()
	c.weapons = WeaponConfig.spec_defaults()
	c.gunnery = RangeConfig.new()
	return c

static func load_all() -> Configs:
	var c := defaults()
	var m := load("res://config/movement.tres") as MovementConfig
	if m != null: c.movement = m
	var h := load("res://config/hardpoint.tres") as HardpointConfig
	if h != null: c.hardpoints = h
	var w := load("res://config/weapons.tres") as WeaponConfig
	if w != null and w.catalog.size() > 0: c.weapons = w
	var g := load("res://config/range.tres") as RangeConfig
	if g != null: c.gunnery = g
	return c
