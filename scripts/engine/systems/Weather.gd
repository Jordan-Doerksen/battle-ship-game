class_name Weather
extends RefCounted
# C17 WEATHER FRONTS (docs/specs/weather-fronts.md) — the seeded front schedule. NOT a Sim.step
# system: weather is per-wave STATE, not per-tick behavior. Main calls generate() once at world
# setup (the C15 Terrain.generate precedent — probes that never call it run clear-sky and stay
# byte-identical to pre-C17); Waves._begin_wave reads the schedule at each wave boundary.
#
# THE DETERMINISM CONTRACT: the whole schedule rolls on a DEDICATED substream keyed off the world
# seed — ZERO world.rng draws (the C16 director precedent), so the combat stream is untouched
# whether weather is enabled, disabled, or ungenerated. Same seed ⇒ same weather, however you fought.

const SUBSTREAM_XOR: int = 0x57583137   # "WX17" — the schedule's private stream key
const MAX_WAVE: int = 400               # far past any real run; the endless ladder never outruns it

# Build world.wx_schedule: { wave:int → state:String } for every front wave. Escalation (owner
# fork 2): state tier and duration grow with depth, gaps shrink. Boss-clear (owner fork 5): an
# every-Nth machine wave is skipped during assignment — a front spanning one parts around it.
static func generate(world: GameWorld, cfg: Configs) -> void:
	world.wx_schedule = {}
	var wc: WeatherConfig = cfg.weather
	if not wc.enabled:
		return
	var wr := Rng.new((int(world.world_seed) ^ SUBSTREAM_XOR) & 0xFFFFFFFF)
	var wave: int = wc.first_front_min \
		+ int(floor(wr.nextf() * float(wc.first_front_max - wc.first_front_min + 1)))
	while wave <= MAX_WAVE:
		var state: String = _roll_state(wr, wc, wave)
		var dmax: int = mini(wc.dur_max, wc.dur_start + wave / 10)   # deeper runs sit under longer fronts
		var dur: int = wc.dur_start + int(floor(wr.nextf() * float(dmax - wc.dur_start + 1)))
		for w in range(wave, wave + dur):
			if wc.boss_clear and cfg.bosses.every_n > 0 and w % cfg.bosses.every_n == 0:
				continue   # weather and machine difficulty never stack (spec — pitfall #5)
			world.wx_schedule[w] = state
		var gap: int = maxi(wc.gap_floor, wc.gap_start - wave / wc.gap_step_every)
		wave += dur + gap

# State tier by depth: rain-only early, squalls mid, thunderheads deep. One draw per front —
# stable draw count keeps the substream trivially auditable.
static func _roll_state(wr: Rng, wc: WeatherConfig, wave: int) -> String:
	var roll: float = wr.nextf()
	if wave < wc.squall_from:
		return "rain"
	if wave < wc.thunder_from:
		return "squall" if roll < 0.6 else "rain"
	return "thunder" if roll < 0.5 else "squall"
