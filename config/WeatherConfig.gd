class_name WeatherConfig
extends Resource
# C17 WEATHER FRONTS (docs/specs/weather-fronts.md) — the light tactical layer's dials. One config
# per system (repo law); instance at config/weather.tres. The SCHEDULE knobs shape Weather.generate's
# seeded front plan (escalating cadence — owner fork 2); the DETECT multipliers are the whole sim
# surface (all-detection, symmetric — owner fork 4); the render tables are the approved TEMPEST rail
# values (design/the-tempest.html, gate 2026-07-12) read one-way by WeatherRender/SfxPlayer.

@export var enabled: bool = true           # false ⇒ Weather.generate emits an empty schedule (byte-identical pre-C17)

# ── the schedule (escalating: first front early-mid run, then heavier/longer/closer) ──
@export var first_front_min: int = 4       # the first front lands in [min..max] (owner: ~wave 4–6)
@export var first_front_max: int = 6
@export var squall_from: int = 8           # before this wave fronts are rain only
@export var thunder_from: int = 14         # from this wave thunderheads enter the roll
@export var dur_start: int = 1             # front duration in waves, growing with depth toward dur_max
@export var dur_max: int = 3
@export var gap_start: int = 4             # clear waves between fronts, shrinking with depth
@export var gap_floor: int = 2
@export var gap_step_every: int = 8        # gap loses 1 per this many waves survived
@export var boss_clear: bool = true        # owner fork 5: the schedule never lands on an every-Nth machine wave

# ── detection multipliers (the sim surface; 1.0 = clear) ──
@export var detect_rain: float = 0.75
@export var detect_squall: float = 0.6
@export var detect_thunder: float = 0.5

@export var ground_bird: bool = true       # owner fork 5: squall+ sends the AIR WING home

# ── render/audio tables (approved TEMPEST rail; one-way reads, never sim inputs) ──
@export var rain_amount: Dictionary = { "rain": 0.35, "squall": 0.8, "thunder": 0.65 }
@export var veil_amount: Dictionary = { "rain": 0.16, "squall": 0.36, "thunder": 0.4 }
@export var wind_amount: Dictionary = { "rain": 0.45, "squall": 0.85, "thunder": 0.8 }
@export var bolt_period: float = 9.0       # mean seconds between strikes (render-side; floor 4 s — WCAG)

func detect_mult(state: String) -> float:
	match state:
		"rain": return detect_rain
		"squall": return detect_squall
		"thunder": return detect_thunder
	return 1.0

func grounds_bird(state: String) -> bool:
	return ground_bird and (state == "squall" or state == "thunder")
