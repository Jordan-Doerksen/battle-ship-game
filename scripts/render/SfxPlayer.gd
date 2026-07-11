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
