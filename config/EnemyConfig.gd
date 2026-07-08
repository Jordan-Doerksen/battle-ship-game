class_name EnemyConfig
extends Resource
# The C3 enemy roster (docs/specs/wave-director.md): swarmer / gunboat / bomber, air + surface only
# (subs wait for the sonar chunk). Instance lives at config/enemies.tres. Per the config-split rule
# this holds enemy stats ONLY; the director's knobs are WaveConfig.

@export var roster: Array[EnemyDef] = []

func by_id(eid: String) -> EnemyDef:
	for e in roster:
		if e.id == eid:
			return e
	return null

# Spec-table roster, for probe/boot fallback when the .tres is unavailable. Values must mirror
# config/enemies.tres exactly. Roster ORDER is part of determinism (the director indexes into it).
static func spec_defaults() -> EnemyConfig:
	var cfg := EnemyConfig.new()
	var sw := EnemyDef.new()
	sw.id = "swarmer"; sw.layer = "air"; sw.hp = 2; sw.speed = 115.0; sw.turn = 2.2
	sw.dmg = 1; sw.radius = 9.0; sw.cost = 1; sw.unlock = 1
	var gb := EnemyDef.new()
	gb.id = "gunboat"; gb.layer = "surf"; gb.hp = 5; gb.speed = 65.0; gb.turn = 1.2
	gb.dmg = 0; gb.radius = 14.0; gb.cost = 3; gb.unlock = 3
	gb.standoff = 500.0; gb.fire_range = 700.0; gb.fire_period = 4.0
	gb.shell_speed = 150.0; gb.shell_dmg = 1; gb.lead = 0.6; gb.spread = 0.05
	var bo := EnemyDef.new()
	bo.id = "bomber"; bo.layer = "air"; bo.hp = 8; bo.speed = 45.0; bo.turn = 0.5
	bo.dmg = 2; bo.radius = 16.0; bo.cost = 5; bo.unlock = 5
	cfg.roster = [sw, gb, bo]
	return cfg
