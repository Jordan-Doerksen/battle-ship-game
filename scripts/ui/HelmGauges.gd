class_name HelmGauges
extends Control
# The gauge bank + sortie HUD — 1:1 with the owner-approved mockups (C2 LOOK-LOCK carried into C3):
# hull pips + grace flicker, engine order, way bar, helm, batteries line; the wave plate (top-left);
# the radar scope with fire-control bearing (bottom-right, C3 gate revisions 1–2); the force-fire
# reticle; and the SHIP LOST card. C12 readability/flow: torpedo wake-dash blips, the DC arm ring +
# rack dial, the PAUSED plate, the advisory plate, and the lost-card misclick guard. Reads the world
# one-way each frame; writes nothing back (Main sets `paused`/`hint`/`lost_report`). Layout
# constants are cosmetic plate geometry, not tunables. This node is the orchestrator: it owns the
# shared consts/state/primitives and dispatches _draw to the render-domain helpers (split per the
# house 500-line rule, mirroring FieldRenderer/SeaRender at C9) — GaugePanel (bottom-left gauges),
# StatusPlates (wave + boss plates), RadarScope (the scope + blips), HudOverlays (lost card, pause,
# advisory, reticle). The helpers reach back into `self` via `g.` (the sanctioned house pattern).

const PLATE_BG := Color(0.051, 0.125, 0.157, 0.88)
const PLATE_EDGE := Color(0.804, 0.729, 0.557, 0.5)
const BRASS := Color(0.804, 0.729, 0.557)
const BRASS_DIM := Color(0.557, 0.506, 0.373)
const FOAM := Color(0.894, 0.941, 0.949)
const RED := Color(0.851, 0.310, 0.169)
const ORANGE := Color(0.914, 0.404, 0.259)
const STEEL := Color(0.576, 0.655, 0.682, 0.85)

const PAD := 18.0
const PLATE_W := 330.0
const PLATE_H := 252.0
const INNER := 16.0
const RADAR_R := 105.0

const FLASH_LIFE := 1.2         # seconds a burst flash lives on the scope
const LOST_GUARD_MS := 1500     # the card holds this long before the restart prompt reveals

var _world: GameWorld
var _cfgs: Configs
var _mono: Font
var _sans: Font
var _shot_flashes: Array = []   # C11 fall-of-shot: own main-battery bursts flash on the scope

# C12 flow: Main sets both per frame (one-way, same channel as everything else here)
var paused: bool = false        # true while the sim holds — the PAUSED plate shows
var hint: String = ""           # the active advisory line ("" = none) — the drip-onboarding plate
var _lost_shown_ms: int = -1    # C12 misclick guard: first frame the lost card drew this run
var _boss_seen_ms: int = -1     # render-side: when the current machine first appeared (plate flash)
var lost_report: Dictionary = {}   # Main fills at run end: { xp: int, leveled_to: int (0 = none) }

func bind(world: GameWorld, cfgs: Configs) -> void:
	_world = world
	_cfgs = cfgs
	_shot_flashes.clear()
	_lost_shown_ms = -1
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Cascadia Mono", "Menlo", "Consolas", "monospace"])
	_mono = mono
	_sans = ThemeDB.fallback_font

# C11: Main hands the sim's effect batch here too (same one-way channel as FieldRenderer) —
# the scope keeps only what it paints: friendly main-battery bursts, as fall-of-shot flashes.
func consume_effects(events: Array) -> void:
	var now: int = Time.get_ticks_msec()
	for e in events:
		if e["type"] == "splash" and not e.get("hostile", false) and e.get("r", 0.0) >= 28.0:
			_shot_flashes.append({ "pos": e["pos"], "t0": now })
	while _shot_flashes.size() > 24:
		_shot_flashes.pop_front()

func _order_label() -> String:
	if _world.input.force_all:
		return "ALL GUNS"
	if _world.input.force_large and _world.input.force_medium:
		return "MAIN + SECONDARY"
	if _world.input.force_large:
		return "MAIN BATTERY"
	if _world.input.force_medium:
		return "SECONDARIES"
	return ""

func _draw() -> void:
	if _world == null:
		return
	GaugePanel.draw(self)
	StatusPlates.draw_wave(self)
	StatusPlates.draw_boss(self)
	RadarScope.draw(self)
	if _world.run_over:
		HudOverlays.draw_lost_card(self)
	else:
		_lost_shown_ms = -1   # self-heals across restarts even if bind() isn't re-run
		HudOverlays.draw_reticle(self)
		if hint != "":
			HudOverlays.draw_hint(self)
		if paused:
			HudOverlays.draw_pause(self)

# ── shared plate/label helpers (used by every render-domain helper via `g.`) ──
func _draw_plate(pos: Vector2, sz: Vector2) -> void:
	var c := 10.0
	var pts := PackedVector2Array([
		pos + Vector2(c, 0), pos + Vector2(sz.x, 0), pos + Vector2(sz.x, sz.y - c),
		pos + Vector2(sz.x - c, sz.y), pos + Vector2(0, sz.y), pos + Vector2(0, c),
	])
	draw_colored_polygon(pts, PLATE_BG)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, PLATE_EDGE, 1.0, true)

func _label(x: float, y: float, text: String) -> void:
	var cx := x
	for ch in text:
		draw_string(_sans, Vector2(cx, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, BRASS_DIM)
		cx += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 2.5

func _centered_spaced(cx: float, y: float, text: String, px: int, col: Color, tracking: float) -> void:
	var total := 0.0
	for ch in text:
		total += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking
	var x := cx - total * 0.5
	for ch in text:
		draw_string(_sans, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		x += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking
