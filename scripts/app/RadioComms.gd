class_name RadioComms
extends RefCounted
# THE FLEET RADIO (app domain) — the narrative comms voice of TF50 ACTUAL, Fleet Command over the
# satellite net. Owned by Main; it ABSORBS the C12 contextual-drip hints (the old single advisory
# plate is retired) into a rolling 3-line log with a per-message typewriter reveal, drives the dish
# pulse + chime on incoming traffic, and holds the strait's grounded holdout-thriller voice.
#
# STRICTLY ONE-WAY (the C12 hint contract, same rails): tick() READS world/cfg/profile state and
# NEVER writes the sim or touches world.rng — the determinism probes stay byte-identical. The only
# thing it persists is profile.seen_hints (app-layer, the sim never reads the profile), exactly as
# Main._check_hints did before. Time stamps come off the render/app clock (Time.get_ticks_msec),
# never the sim clock. Ticked only in Main's "game" state — the attract war runs radio-silent.

const LOG_CAP := 3            # the panel shows the last three lines; older scroll off
const MS_PER_CHAR := 22       # typewriter reveal cadence (per char, the newest line only)
const RELIEF_PERIOD := 75.0   # the spine: a relief line every ~75 s of sortie — it cycles, never resolves
const OBSTACLE_NEAR := 260.0  # shoal-water advisory range (ship edge-distance to a terrain feature)

# The C12 drip hints, reworded as fleet guidance (verbatim from the fleet-radio spec). Keyed by the
# same 5 ids Main._check_hints used, so profile.seen_hints stays compatible (once per profile).
const HINTS := {
	"helm": "she answers slow — that's the tonnage, not you. brake early.",
	"force": "hold left trigger and every gun follows your cursor. right trigger, the main battery alone.",
	"deep": "no gun reaches the deep. drive your stern over the contact — the racks do the rest.",
	"torpedo": "torpedo in the water. turn into it, or outrun it.",
	"machine": "big return — that's no drone. shoot its parts off first; the core's soft until they fall.",
}

# The relief cycle — the holdout's heartbeat. Advances one line each period, loops forever.
const RELIEF_LINES := [
	"relief is forty mikes out. hold what you have.",
	"relief delayed — still forty mikes. hold.",
	"we have your position. relief is forty mikes out.",
	"TF50 is inbound. forty mikes. we're coming.",
]

var signal_ms: int = -100000   # tick of the last push — for the dish pulse (Main also stamps _field)

var _log: Array = []           # [{ "text": String, "t0": int }] — newest last, capped at LOG_CAP
var _queue: Array = []         # deferred lines — only ONE push lands per frame, extras wait here
var _signal_pending: bool = false   # a fresh message awaits its chime (consume_signal drains it)

# trigger latches (reset() clears them at every sortie start)
var _opened: bool = false           # SORTIE OPEN fired
var _prev_wave_state: String = ""   # last-seen world.wave_state, to catch lull↔fighting flips
var _boss_announced: bool = false   # the current machine already got its arrival line
var _obstacle_seen: bool = false    # the shoal advisory fired this sortie
var _relief_idx: int = 0            # which relief line comes next
var _relief_next: float = RELIEF_PERIOD   # sortie elapsed at which the next relief line fires

func reset() -> void:   # Main calls this in start_sortie — a fresh net for every strait picket
	_log.clear()
	_queue.clear()
	_signal_pending = false
	_opened = false
	_prev_wave_state = ""
	_boss_announced = false
	_obstacle_seen = false
	_relief_idx = 0
	_relief_next = RELIEF_PERIOD

# Append a line to the log (cap at LOG_CAP), stamp it, and flag a fresh signal for the dish + chime.
func push(text: String) -> void:
	_log.append({ "text": text, "t0": Time.get_ticks_msec() })
	while _log.size() > LOG_CAP:
		_log.pop_front()
	signal_ms = Time.get_ticks_msec()
	_signal_pending = true

# Evaluate every trigger once per frame (Main's game state, not paused, not run_over), then land AT
# MOST one queued line so messages never stack instantly. `_main` is accepted for parity with the
# call site but the engine reads only world/cfg/profile (one-way).
func tick(world: GameWorld, cfg: Configs, profile: Profile, _main: Node) -> void:
	_evaluate(world, cfg, profile)
	if not _queue.is_empty():
		push(_queue.pop_front())

# All triggers enqueue through _emit; the queue drain in tick() paces them out one per frame.
func _evaluate(world: GameWorld, cfg: Configs, profile: Profile) -> void:
	# SORTIE OPEN — the first tick of the picket
	if not _opened:
		_opened = true
		_emit("TF50 ACTUAL — we have your picket. hold the strait.")
	# WAVE FORMING / WAVE CLEAR — the lull↔fighting flips (a new wave, then the water going quiet)
	if _prev_wave_state == "lull" and world.wave_state == "fighting":
		var bearing: int = ((world.wave * 47) + (world.world_seed % 360)) % 360   # cosmetic derived reading, no rng draw
		var vanguard: Variant = world.wave_lines.get("vanguard", [])
		var formation: String = "wave forming"
		if vanguard is Array and not (vanguard as Array).is_empty():
			formation = String((vanguard as Array)[0]).to_lower()
		_emit("contacts massing, bearing %03d — %s. stand to." % [bearing, formation])
	elif _prev_wave_state == "fighting" and world.wave_state == "lull":
		_emit("water's clear. good shooting. for now.")
	_prev_wave_state = world.wave_state
	# BOSS ARRIVAL — once per machine (re-arms when the current machine is down)
	if world.boss != null:
		if not _boss_announced:
			_boss_announced = true
			_emit("priority target on the scope — %s. weapons free." % Bosses.def_of(world, cfg).display_name)
	else:
		_boss_announced = false
	# TEACHING — the absorbed C12 drip, once per profile (profile.seen_hints)
	if world.elapsed > 1.0:
		_teach("helm", profile)
	if world.elapsed > 9.0:
		_teach("force", profile)
	for en in world.enemies:   # deep: any active sub inside sonar reach (the C12 'contact' moment)
		if en.active and en.layer == "sub" and en.pos.distance_to(world.ship_pos) <= cfg.sonar.radius:
			_teach("deep", profile)
			break
	for pr in world.projectiles.items:   # torpedo: any live torpedo run
		if pr.active and pr.wid == "torpedo":
			_teach("torpedo", profile)
			break
	if world.boss != null:   # machine: the first war machine on the water
		_teach("machine", profile)
	# OBSTACLE — first time the hull closes to shoal water (once per sortie)
	if not _obstacle_seen:
		for tf in world.terrain:
			if world.ship_pos.distance_to(tf["pos"]) - float(tf["r"]) <= OBSTACLE_NEAR:
				_obstacle_seen = true
				_emit("shoal water off the bow — mind the rocks.")
				break
	# RELIEF — the spine (cycles, never resolves)
	if world.elapsed >= _relief_next:
		_emit(RELIEF_LINES[_relief_idx % RELIEF_LINES.size()])
		_relief_idx += 1
		_relief_next += RELIEF_PERIOD

# One drip hint, once per profile: enqueue the fleet-guidance line and bank the id so it never repeats.
func _teach(id: String, profile: Profile) -> void:
	if profile.seen_hints.has(id):
		return
	profile.seen_hints.append(id)
	profile.save()
	_emit(HINTS[id])

func _emit(text: String) -> void:
	_queue.append(text)

# The panel's read: each log line with its reveal progress. Only the NEWEST line types out; older
# lines are fully revealed (the panel dims them). reveal ∈ [0,1] off the render clock.
func display_lines() -> Array:
	var now: int = Time.get_ticks_msec()
	var last: int = _log.size() - 1
	var out: Array = []
	for i in range(_log.size()):
		var entry: Dictionary = _log[i]
		var text: String = entry["text"]
		var reveal: float = 1.0
		if i == last:
			var chars: int = maxi(1, text.length())
			reveal = clampf(float(now - int(entry["t0"])) / float(chars * MS_PER_CHAR), 0.0, 1.0)
		out.append({ "text": text, "reveal": reveal, "newest": i == last })
	return out

# True exactly once after each push — Main plays the chime + kicks the dish once per incoming line.
func consume_signal() -> bool:
	if _signal_pending:
		_signal_pending = false
		return true
	return false
