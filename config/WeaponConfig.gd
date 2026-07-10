class_name WeaponConfig
extends Resource
# The C2 weapon catalog (docs/specs/hardpoint-hull.md) — 3 starters, one per mount size. Instance
# lives at config/weapons.tres. Per the config-split rule in `config/SimConfig.gd`, this file holds
# weapon stats ONLY; the mount plan is HardpointConfig, the practice range is RangeConfig.

@export var catalog: Array[WeaponDef] = []

func by_id(wid: String) -> WeaponDef:
	for w in catalog:
		if w.id == wid:
			return w
	return null

# Spec-table starters, for probe/boot fallback when the .tres is unavailable. Values must mirror
# config/weapons.tres exactly.
static func spec_defaults() -> WeaponConfig:
	var cfg := WeaponConfig.new()
	var aa := WeaponDef.new()
	aa.id = "aa20"; aa.display_name = "VIGILANT 20MM"; aa.size = "S"
	aa.domains = PackedStringArray(["air", "surface"]); aa.policy = "CLOSE"   # CREWED GUNS CR
	aa.range_u = 420.0; aa.rate = 12.0; aa.traverse = 4.0; aa.dmg = 1
	aa.speed = 700.0; aa.spread = 0.14; aa.splash = 0.0
	aa.bloom_add = 0.01; aa.bloom_max = 0.10; aa.bloom_decay = 0.06
	aa.burst_rounds = 10; aa.burst_rest = 1.5; aa.reach_min = 0.4             # person-manned MGs
	var dp := WeaponDef.new()
	dp.id = "dp5"; dp.display_name = "SENTINEL 5-IN"; dp.size = "M"
	dp.domains = PackedStringArray(["air", "surface"]); dp.policy = "CLOSE"
	dp.range_u = 560.0; dp.rate = 1.2; dp.traverse = 2.2; dp.dmg = 2
	dp.speed = 620.0; dp.spread = 0.02; dp.splash = 0.0
	var mb := WeaponDef.new()
	mb.id = "mb16"; mb.display_name = "JUDGEMENT 16-IN"; mb.size = "L"
	mb.domains = PackedStringArray(["surface"]); mb.policy = "STRONG"
	mb.range_u = 900.0; mb.rate = 0.33; mb.traverse = 0.9; mb.dmg = 4
	mb.speed = 420.0; mb.spread = 0.012; mb.splash = 36.0
	cfg.catalog = [aa, dp, mb]
	return cfg
