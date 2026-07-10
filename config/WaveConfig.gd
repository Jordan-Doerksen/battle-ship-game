class_name WaveConfig
extends Resource
# Wave-director tunables. C3 shipped the seeded budget director; C16 THE WAR, REPACKED
# (docs/specs/the-war-repacked.md) supersedes the greedy blob spend with FORMATION TEMPLATES
# assigned to ECHELONS (vanguard → main body → sting) staged down open-water lanes or as
# ambushes behind terrain, with a genuinely longer QUIET between waves. Instance lives at
# config/waves.tres. Per the config-split rule, enemy stats live in EnemyConfig.

@export var base_budget: int = 6          # wave 1 threat points
@export var budget_per_wave: int = 4      # added points per wave
@export var first_wave_delay: float = 3.0 # seconds before wave 1 arrives
@export var spawn_ring_min: float = 1700.0  # arrival distance — beyond the view edge (formation ring + boss/Main use it)
@export var spawn_ring_max: float = 2000.0
@export var hull_pips: int = 10           # run health (D1.8: one pool, pip-style)
@export var grace_secs: float = 0.8       # post-hit invulnerability window
@export var radar_range: float = 2200.0   # scope reach — covers the spawn ring

# C16 THE WAR, REPACKED — echelon rhythm + the real quiet + the ambush roll.
@export var main_delay: float = 15.0      # main body lands this many s behind the vanguard
@export var sting_delay: float = 28.0     # the sting lands this many s behind the vanguard
@export var quiet_secs: float = 12.0      # the REAL QUIET between waves (was C3's lull_secs=8) — nothing arrives
@export var ambush_chance: float = 0.35   # per ambush_ok formation, odds it stages behind a feature when one exists

# LEGACY (C3) — the greedy director's knobs. The C16 director no longer reads these, but they are
# kept LIVE because the attract override (scripts/app/Main.gd) still sets them: lull_secs → a short
# demo breather (now supersede via quiet_secs there), cluster_min/max → "every bearing at once".
# Removing them would break Main.gd's compile. Not dead: read outside this domain.
@export var lull_secs: float = 8.0        # superseded by quiet_secs for the director; Main's attract still writes it
@export var cluster_min: int = 1          # C3 attack-bearing count; unused by the C16 director
@export var cluster_max: int = 3

# THE TEMPLATE TABLE (docs/specs/the-war-repacked.md §1). Config-as-data lives here as a method,
# not exported .tres fields — a typed Array[Dictionary] of formations is awkward to author in a
# .tres literal, so it lives in code like EnemyConfig.spec_defaults(). Each formation:
#   name       display label (newsreel voice)
#   members    Array of { type, n, delay } — delay = seconds this group lands AFTER the formation's
#              echelon time (the screened advance: the JACKAL LINE trails its GNAT SCREEN by 8 s)
#   shape      "wedge" (a V at the ship) · "line" (abreast) · "loose" (jittered echelon) ·
#              "split:DEG" (two anchor bearings DEG apart — a pincer/anvil; each half is a line)
#   spacing    unit spacing along the shape (u)
#   min_wave   first wave this formation may appear (also gates its member unlocks)
#   ambush_ok  may stage behind a terrain feature instead of arriving down a lane
#   echelon    "vanguard" (0 s) · "main" (+main_delay) · "sting" (+sting_delay)
#   weight     draw weight in the weighted template spend (a tuning column, all near 1)
#   flank      (optional) anchor bears ~70–110° off the wave's dominant bearing
# Template cost = Σ member costs (Waves._tpl_cost); the budget spends exactly (singles fill the rest).
func templates() -> Array:
	return [
		{ "name": "GNAT SWARM", "members": [{ "type": "swarmer", "n": 5, "delay": 0.0 }],
		  "shape": "wedge", "spacing": 46.0, "min_wave": 1, "ambush_ok": false, "echelon": "vanguard", "weight": 1.0 },
		{ "name": "GNAT SCREEN + JACKAL LINE", "members": [{ "type": "swarmer", "n": 4, "delay": 0.0 }, { "type": "gunboat", "n": 2, "delay": 8.0 }],
		  "shape": "line", "spacing": 70.0, "min_wave": 3, "ambush_ok": false, "echelon": "vanguard", "weight": 1.2 },
		{ "name": "JACKAL PINCER", "members": [{ "type": "gunboat", "n": 2, "delay": 0.0 }],
		  "shape": "split:70", "spacing": 0.0, "min_wave": 3, "ambush_ok": true, "echelon": "main", "weight": 1.0 },
		{ "name": "WASP FLIGHT", "members": [{ "type": "wasp", "n": 3, "delay": 0.0 }],
		  "shape": "loose", "spacing": 60.0, "min_wave": 4, "ambush_ok": false, "echelon": "sting", "weight": 0.9, "flank": true },
		{ "name": "VULTURE RAID", "members": [{ "type": "bomber", "n": 2, "delay": 0.0 }],
		  "shape": "split:170", "spacing": 0.0, "min_wave": 5, "ambush_ok": false, "echelon": "main", "weight": 0.8 },
		{ "name": "WOLFPACK", "members": [{ "type": "sub", "n": 2, "delay": 0.0 }],
		  "shape": "line", "spacing": 160.0, "min_wave": 7, "ambush_ok": true, "echelon": "main", "weight": 0.7 },
	]
