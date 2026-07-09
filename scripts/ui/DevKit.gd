class_name DevKit
extends Control
# DEV TEST KIT (C4, owner request) — DEBUG BUILDS ONLY (Main only instantiates it when
# OS.is_debug_build()). Toggle with ` (backquote) during a sortie. The two sim intercepts it uses
# (world.godmode / world.freeze_waves) default off, so untouched runs stay deterministic; manual
# spawns use their OWN RNG, never world.rng. Enabling any cheat voids same-seed repro for that run.

const FOAM := Color(0.894, 0.941, 0.949)
const BRASS := Color(0.804, 0.729, 0.557)
const BRASS_DIM := Color(0.557, 0.506, 0.373)
const DEV := Color(0.435, 0.357, 0.839)      # the kit is deliberately off-palette: it isn't the game

var _main: Node
var _sans: Font
var _mono: Font
var _hits: Array = []
var _rng := RandomNumberGenerator.new()      # NON-sim randomness for spawn bearings

const ROWS := [
	["INVULN", "FREEZE", "GODGUNS"],
	["+SWARMER", "+GUNBOAT", "+BOMBER", "+SUB", "SWARM x8"],
	["KILL ALL", "NEXT WAVE", "HEAL", "MAX LVL"],
]

func bind(main: Node) -> void:
	_main = main
	_sans = ThemeDB.fallback_font
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Menlo", "Consolas", "monospace"])
	_mono = mono
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.randomize()
	visible = false

func _toggled_on(label: String) -> bool:
	var w: GameWorld = _main.world
	match label:
		"INVULN": return w != null and w.godmode
		"FREEZE": return w != null and w.freeze_waves
		"GODGUNS": return _main.god_guns
	return false

func _draw() -> void:
	_hits.clear()
	var pw := 470.0
	var x0 := (size.x - pw) * 0.5
	var y := 12.0
	var ph := 14.0 + ROWS.size() * 32.0 + 10.0
	draw_rect(Rect2(x0, y, pw, ph), Color(0.024, 0.071, 0.094, 0.94))
	draw_rect(Rect2(x0, y, pw, ph), DEV, false, 1.0)
	draw_string(_sans, Vector2(x0 + 12.0, y + 16.0), "◆ TEST KIT   ` to hide", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DEV)
	var ry := y + 26.0
	for row in ROWS:
		var bx := x0 + 12.0
		for label in row:
			var bw: float = _mono.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 20.0
			var r := Rect2(bx, ry, bw, 24.0)
			var on := _toggled_on(label)
			if on:
				draw_rect(r, DEV)
			draw_rect(r, DEV if on else BRASS_DIM, false, 1.0)
			draw_string(_mono, Vector2(r.position.x + 10.0, r.get_center().y + 4.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, FOAM if on else BRASS)
			_hits.append({ "rect": r, "id": label })
			bx += bw + 8.0
		ry += 32.0

func _spawn(type_id: String, n: int) -> void:
	var w: GameWorld = _main.world
	var cfg: Configs = _main.cfgs
	for i in range(n):
		var def: EnemyDef = cfg.enemies.by_id(type_id)
		var e := Enemy.new()
		e.type_id = def.id
		e.layer = def.layer
		e.hp = def.hp
		e.hp_max = def.hp
		e.active = true
		var ang: float = _rng.randf() * TAU
		var dist: float = 650.0 + _rng.randf() * 350.0
		e.pos = w.ship_pos + Vector2(sin(ang), -cos(ang)) * dist
		e.heading = atan2(w.ship_pos.x - e.pos.x, -(w.ship_pos.y - e.pos.y))
		w.enemies.append(e)
	if w.wave_state == "lull":
		w.wave_state = "fighting"

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var w: GameWorld = _main.world
	if w == null or w.run_over:
		return
	for h in _hits:
		if not h["rect"].has_point(event.position):
			continue
		match h["id"]:
			"INVULN": w.godmode = not w.godmode
			"FREEZE": w.freeze_waves = not w.freeze_waves
			"GODGUNS": _main.toggle_god_guns()
			"+SWARMER": _spawn("swarmer", 1)
			"+GUNBOAT": _spawn("gunboat", 1)
			"+BOMBER": _spawn("bomber", 1)
			"+SUB": _spawn("sub", 1)
			"SWARM x8": _spawn("swarmer", 8)
			"KILL ALL":
				for e in w.enemies:
					e.active = false
			"NEXT WAVE":
				for e in w.enemies:
					e.active = false
				w.wave_state = "lull"
				w.lull_until = w.elapsed
				w.freeze_waves = false
			"HEAL": w.hull = _main.cfgs.waves.hull_pips
			"MAX LVL": _main.dev_max_level()
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
