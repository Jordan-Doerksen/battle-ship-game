class_name SfxPlayer
extends Node
# C12 sound (docs/specs/readability-feel.md §3) — the presentation end of the one-way effect
# channel. Consumes the SAME batch Main plumbs to Field/Gauges (C11) and maps event types to the
# baked streams (tools/gen_sfx.py → audio/*.wav) with per-sound min-gap rate limits from
# audio.tres. Reads the world's events, writes nothing back; sounds duplicate visual information,
# never carry it alone — mute loses nothing but feel. `klaxon` and `waveclear`, emitted and
# dropped since C3, finally sound here.

const POOL_SIZE := 10
const SOUND_NAMES := [
	"mb16_fire", "dp5_fire", "mg_burst", "splash_column", "gunsplash", "torp_klaxon",
	"contact_ping", "dc_volley", "dc_blast", "ship_hit", "wave_clear", "machine_swell", "ship_lost",
	"rain_bed", "thunder",   # C17 weather fronts — the bed loops, thunder rumbles on its own clock
]
# UI cues — played directly by Main (play_ui), NOT routed through the sim's effect channel. The
# FLEET RADIO chime on incoming comms traffic lives here.
const UI_NAMES := ["radio"]
# event type → sound name; "muzzle" routes by its size tag instead (L/M/S per Turrets.gd)
const EVENT_SOUND := {
	"splash": "splash_column", "gunsplash": "gunsplash",
	"torpwater": "torp_klaxon", "contact": "contact_ping",
	"dcvolley": "dc_volley", "dcblast": "dc_blast",
	"shiphit": "ship_hit", "shipdeath": "ship_lost",
	"waveclear": "wave_clear", "klaxon": "machine_swell",   # the klaxon event IS the machine arrival (Waves.gd)
}
const MUZZLE_SOUND := { "L": "mb16_fire", "M": "dp5_fire", "S": "mg_burst" }

var _cfg: AudioConfig
var _streams: Dictionary = {}     # sound name → AudioStream
var _pool: Array = []             # AudioStreamPlayer children
var _pool_started: Array = []     # per-player start tick (ms) — steal the oldest when all busy
var _last_ms: Dictionary = {}     # sound name → last play tick (ms), the min-gap ledger
# C17 weather bed — a dedicated looping voice outside the one-shot pool, plus the thunder clock.
# States map to bed volumes; thunder rumbles are DECOUPLED from the visual bolts on purpose
# (thunder lags lightning in life too — an untied rumble every 6–15 s reads true).
const WX_BED_VOL := { "rain": 0.30, "squall": 0.55, "thunder": 0.50 }
var _wx_bed: AudioStreamPlayer
var _wx_state: String = "clear"
var _wx_last_set: int = -100000   # watchdog: Main stops calling set_weather → the bed stops itself
var _wx_next_rumble: int = 0

func _ready() -> void:
	for snd in SOUND_NAMES:
		_streams[snd] = load("res://audio/%s.wav" % snd)
	for snd in UI_NAMES:
		_streams[snd] = load("res://audio/%s.wav" % snd)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
		_pool_started.append(0)
	_wx_bed = AudioStreamPlayer.new()
	add_child(_wx_bed)
	var bed: AudioStreamWAV = _streams.get("rain_bed") as AudioStreamWAV
	if bed != null:   # loop the whole bed (16-bit mono: 2 bytes per frame)
		bed.loop_mode = AudioStreamWAV.LOOP_FORWARD
		bed.loop_begin = 0
		bed.loop_end = bed.data.size() / 2
		_wx_bed.stream = bed

func _process(_dt: float) -> void:
	# the watchdog: leaving the game state (menus, manual, restart) silences the front
	if _wx_state != "clear" and Time.get_ticks_msec() - _wx_last_set > 600:
		_wx_state = "clear"
		_wx_bed.stop()

# Main pushes the current weather state every game frame (C17). Bed volume rides the state;
# THUNDERHEAD schedules low rumbles on the render clock (cosmetic — never the sim's).
func set_weather(state: String) -> void:
	_wx_last_set = Time.get_ticks_msec()
	if _cfg == null or _cfg.muted:
		state = "clear"
	if state != _wx_state:
		_wx_state = state
		if state == "clear" or not WX_BED_VOL.has(state):
			_wx_bed.stop()
		else:
			_wx_bed.volume_db = linear_to_db(clampf(_cfg.master_volume * float(WX_BED_VOL[state]), 0.0001, 1.0))
			if not _wx_bed.playing:
				_wx_bed.play()
			_wx_next_rumble = Time.get_ticks_msec() + 2000
	elif _wx_bed.playing and _cfg != null:
		_wx_bed.volume_db = linear_to_db(clampf(_cfg.master_volume * float(WX_BED_VOL.get(state, 0.0)), 0.0001, 1.0))
	if _wx_state == "thunder" and Time.get_ticks_msec() >= _wx_next_rumble:
		_wx_next_rumble = Time.get_ticks_msec() + 6000 + randi() % 9000
		_play("thunder")

func bind(cfg: AudioConfig) -> void:
	_cfg = cfg

func consume_effects(events: Array, world_elapsed: float) -> void:
	if _cfg == null or _cfg.muted:
		return
	for e in events:
		var sound: String = ""
		if e["type"] == "muzzle":
			sound = MUZZLE_SOUND.get(e.get("size", ""), "")
		else:
			sound = EVENT_SOUND.get(e["type"], "")   # unmapped events stay silent by design
		if sound != "":
			_play(sound)

# A direct UI cue (the FLEET RADIO chime) — Main calls this on incoming comms, bypassing the sim
# effect channel. Same pool + master_volume/mute as everything else; naturally rate-limited by the
# radio (one line per frame max), so it needs no min-gap ledger entry.
func play_ui(key: String) -> void:
	if _cfg == null or _cfg.muted:
		return
	if _streams.has(key):
		_play(key)

func _play(sound: String) -> void:
	var now: int = Time.get_ticks_msec()
	var gap_ms: int = int(float(_cfg.min_gap.get(sound, 0.0)) * 1000.0)
	if _last_ms.has(sound) and now - int(_last_ms[sound]) < gap_ms:
		return
	_last_ms[sound] = now
	var slot: int = -1
	for i in _pool.size():         # first idle player…
		if not _pool[i].playing:
			slot = i
			break
	if slot < 0:                   # …or steal the oldest voice
		slot = 0
		for i in _pool.size():
			if _pool_started[i] < _pool_started[slot]:
				slot = i
	var p: AudioStreamPlayer = _pool[slot]
	p.stream = _streams[sound]
	p.volume_db = linear_to_db(clampf(_cfg.master_volume, 0.0001, 1.0))
	p.play()
	_pool_started[slot] = now
