class_name EnemyConfig
extends Resource
# The enemy roster (docs/specs/{wave-director,sonar-subs}.md): swarmer / gunboat / bomber / sub —
# all three D1.9 domains. Instance lives at config/enemies.tres. Per the config-split rule this
# holds enemy stats ONLY; the director's knobs are WaveConfig, sonar/ASW knobs are SonarConfig.

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
	var su := EnemyDef.new()
	su.id = "sub"; su.layer = "sub"; su.hp = 6; su.speed = 35.0; su.turn = 0.5
	su.dmg = 0; su.radius = 16.0; su.cost = 6; su.unlock = 7
	su.standoff = 600.0; su.fire_range = 800.0; su.fire_period = 8.0
	su.shell_speed = 130.0; su.shell_dmg = 2; su.lead = 0.5; su.spread = 0.03
	su.torp_run = 900.0
	cfg.roster = [sw, gb, bo, su]
	return cfg
