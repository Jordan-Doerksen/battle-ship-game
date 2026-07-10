class_name AudioConfig
extends Resource
# C12 sound (docs/specs/readability-feel.md §3). Instance lives at config/audio.tres. Per the
# config-split rule this holds the mixer tunables ONLY; the sounds themselves are baked WAVs
# (tools/gen_sfx.py → audio/, from the mockup's approved recipes). min_gap is the per-sound rate
# limit SfxPlayer enforces so the crewed MGs can't machine-gun the mixer — seconds between plays,
# keyed by sound name (= wav basename), missing key ⇒ no limit.

@export var master_volume: float = 0.8    # linear 0..1; SfxPlayer converts to dB
@export var muted: bool = false
@export var min_gap: Dictionary = {
	"mb16_fire": 0.12,
	"dp5_fire": 0.12,
	"mg_burst": 0.9,       # one burst SOUND per crewed-MG burst, not per muzzle event
	"splash_column": 0.25,
	"gunsplash": 0.08,     # repeats at this gap stitch the mockup's walking line
	"torp_klaxon": 3.0,
	"contact_ping": 1.0,
	"dc_volley": 0.5,
	"dc_blast": 0.3,
	"ship_hit": 0.2,
	"wave_clear": 1.0,
	"machine_swell": 2.0,
	"ship_lost": 2.0,
}
