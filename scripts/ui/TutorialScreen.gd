class_name TutorialScreen
extends Control
# The FIELD MANUAL (C13): a paged training-film screen — one mechanic per page, the locked copy,
# and a live looping vignette beneath it. The demos themselves live in TutorialVignettes (split
# out per the house file-size rule); this file owns the chrome (plate, copy, dots, arrows) and
# the PROP SHOP — the miniature art the vignettes stage (hull/turret/gunboat/sub/helo cribbed
# from ShipRender/HostileRender, splash language from FxRender). Main owns the state machine and
# routes the keys (←/→ or A/D flip, ESC/M return); this side adds clickable ‹ › arrows and page
# dots (the TitleScreen hit-test pattern). Self-clocked: a local accumulator advances in _process
# while visible; under FieldConfig.reduced_motion the clock HOLDS at a readable mid-loop frame —
# the film becomes a still.

const FOAM := Color(0.894, 0.941, 0.949)
const RED := Color(0.851, 0.310, 0.169)
const ORANGE := Color(0.914, 0.404, 0.259)
const BRASS := Color(0.804, 0.729, 0.557)
const BRASS_DIM := Color(0.557, 0.506, 0.373)
const STEEL := Color(0.576, 0.655, 0.682)
const HULL := Color(0.235, 0.310, 0.341)
const DECK := Color(0.353, 0.439, 0.478)
const FLASH := Color(0.910, 0.706, 0.431)
const DARK := Color(0.094, 0.165, 0.212)
const PLATE_BG := Color(0.051, 0.125, 0.157, 0.92)
const PLATE_EDGE := Color(0.804, 0.729, 0.557, 0.5)
const SEA := Color(0.039, 0.118, 0.157)   # #0A1E28 — the vignette water

const PANEL_W := 700.0
const PANEL_H := 280.0
const STILL_T := 5.2   # the frozen frame under reduced motion — chosen so every page reads

const PAGES := [
	{ "title": "THE HELM", "copy": [
		"W A S D. The ship answers slowly — momentum is the whole game.",
		"Brake harder than you think, earlier than you think." ] },
	{ "title": "THE BATTERIES", "copy": [
		"The guns aim themselves. HOLD LMB to put every barrel on the cursor.",
		"RMB — the main battery alone. MMB — the secondaries." ] },
	{ "title": "LONG-RANGE FIRE", "copy": [
		"Inside 900 units the main battery bursts where you point.",
		"Beyond that, shells fly the bearing to max range.",
		"Read your splashes. Walk them on." ] },
	{ "title": "THE CREWED GUNS", "copy": [
		"The 20-millimeter crews fire in bursts and miss like humans.",
		"Their misses stitch the water. Their hits are yours to arrange." ] },
	{ "title": "THE DEEP", "copy": [
		"No gun reaches under the water. Sonar hears to 350 units;",
		"a latched contact arms the stern racks.",
		"Drive over the diamond — the charges do the rest." ] },
	{ "title": "TORPEDOES", "copy": [
		"A LAMPREY fires from beyond your ears. A VULTURE drops them",
		"from the sky. The wake is the warning. Turn into it, or outrun it." ] },
	{ "title": "THE AIR WING", "copy": [
		"The bird flies itself: dips its ears, marks the deep,",
		"softens what it finds. Your stern racks finish what it starts." ] },
	{ "title": "THE MACHINES", "copy": [
		"Every few waves, a war machine. Shoot the parts off first —",
		"the core is soft until they fall." ] },
	{ "title": "THE SCOPE", "copy": [
		"Solid ring — your ears. Dashed foam — the racks' reach.",
		"Dashed brass — the main battery. The rectangle is what you can see.",
		"Everything else is what you can't." ] },
]

var mono: Font   # TutorialVignettes reads these + the prop shop (the ShipRender host pattern)
var sans: Font
var _cfg: FieldConfig
var _page: int = 0
var _t: float = 0.0
var _btn_prev := Rect2()
var _btn_next := Rect2()
var _dot_hits: Array = []   # Rect2 per page dot, rebuilt each draw

func bind(field_cfg: FieldConfig) -> void:
	_cfg = field_cfg
	sans = ThemeDB.fallback_font
	var m := SystemFont.new()
	m.font_names = PackedStringArray(["DejaVu Sans Mono", "Cascadia Mono", "Menlo", "Consolas", "monospace"])
	mono = m
	mouse_filter = Control.MOUSE_FILTER_STOP

func open() -> void:   # Main calls before showing — the manual always opens at page one
	_page = 0
	_reset_clock()

func flip(dir: int) -> void:
	var next: int = clampi(_page + dir, 0, PAGES.size() - 1)
	if next == _page:
		return
	_page = next
	_reset_clock()
	queue_redraw()

func _reset_clock() -> void:   # each page's film starts from its opening beat, deterministically
	_t = STILL_T if (_cfg != null and _cfg.reduced_motion) else 0.0

func _process(delta: float) -> void:
	if not visible:
		return
	if _cfg == null or not _cfg.reduced_motion:
		_t += delta   # the manual's own clock — no sim, no Time.*, loops replay identically
	queue_redraw()

# ── chrome ──
func _spaced(cx: float, y: float, text: String, px: int, col: Color, tracking: float) -> void:
	var total := 0.0
	for ch in text:
		total += sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking
	var x := cx - total * 0.5
	for ch in text:
		draw_string(sans, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		x += sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking

func _plate(pos: Vector2, sz: Vector2) -> void:
	var cc := 12.0
	var pts := PackedVector2Array([
		pos + Vector2(cc, 0), pos + Vector2(sz.x, 0), pos + Vector2(sz.x, sz.y - cc),
		pos + Vector2(sz.x - cc, sz.y), pos + Vector2(0, sz.y), pos + Vector2(0, cc),
	])
	draw_colored_polygon(pts, PLATE_BG)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	draw_polyline(closed, PLATE_EDGE, 1.0, true)

func _chevron(rect: Rect2, dir: int, live: bool) -> void:
	var col := Color(BRASS.r, BRASS.g, BRASS.b, 0.9 if live else 0.22)
	var c := rect.get_center()
	var tip := c + Vector2(7.0 * dir, 0.0)
	draw_polyline(PackedVector2Array([
		tip + Vector2(-14.0 * dir, -14.0), tip, tip + Vector2(-14.0 * dir, 14.0),
	]), col, 2.0, true)
	draw_rect(rect, Color(BRASS_DIM.r, BRASS_DIM.g, BRASS_DIM.b, 0.35 if live else 0.12), false, 1.0)

func _draw() -> void:
	if mono == null:
		return
	# dark wash — the manual reads over whatever war sits frozen behind it
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.016, 0.055, 0.075, 0.72))
	var cx := size.x * 0.5
	var pw := 880.0
	var ph := 600.0
	var origin := Vector2(cx - pw * 0.5, (size.y - ph) * 0.5)
	_plate(origin, Vector2(pw, ph))
	_spaced(cx, origin.y + 46.0, "★ FIELD MANUAL · PAGE %d/%d" % [_page + 1, PAGES.size()], 10, BRASS_DIM, 3.0)
	_spaced(cx, origin.y + 92.0, String(PAGES[_page]["title"]), 30, FOAM, 8.0)
	var lines: Array = PAGES[_page]["copy"]
	var y := origin.y + 116.0
	for line in lines:
		var ls := String(line)
		y += 20.0
		draw_string(mono, Vector2(cx - mono.get_string_size(ls, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x * 0.5, y),
			ls, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	# the vignette panel sits in a FIXED slot whatever the copy length — the page never reflows
	var pr := Rect2(cx - PANEL_W * 0.5, origin.y + 206.0, PANEL_W, PANEL_H)
	draw_rect(pr, SEA)
	draw_rect(pr, PLATE_EDGE, false, 1.0)
	TutorialVignettes.draw_page(self, _page, pr, _t)
	var film := "TRAINING FILM · STILL" if (_cfg != null and _cfg.reduced_motion) else "TRAINING FILM · LOOPS"
	draw_string(mono, Vector2(pr.end.x - mono.get_string_size(film, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x,
		pr.position.y - 6.0), film, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, BRASS_DIM)
	# ‹ › page arrows — dim at the covers, still safe to click (flip clamps)
	_btn_prev = Rect2(origin.x + 12.0, pr.position.y + PANEL_H * 0.5 - 36.0, 44.0, 72.0)
	_btn_next = Rect2(origin.x + pw - 56.0, pr.position.y + PANEL_H * 0.5 - 36.0, 44.0, 72.0)
	_chevron(_btn_prev, -1, _page > 0)
	_chevron(_btn_next, 1, _page < PAGES.size() - 1)
	# page dots
	_dot_hits.clear()
	var dy := pr.end.y + 30.0
	var dx := cx - float(PAGES.size() - 1) * 11.0
	for i in range(PAGES.size()):
		var p := Vector2(dx + i * 22.0, dy)
		if i == _page:
			draw_circle(p, 4.0, RED)
		else:
			draw_arc(p, 3.0, 0.0, TAU, 12, BRASS_DIM, 1.0, true)
		_dot_hits.append(Rect2(p.x - 9.0, p.y - 9.0, 18.0, 18.0))
	_spaced(cx, pr.end.y + 62.0, "← → — TURN PAGE     ESC / M — RETURN TO TITLE", 9, BRASS_DIM, 2.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _btn_prev.has_point(event.position):
			flip(-1)
		elif _btn_next.has_point(event.position):
			flip(1)
		else:
			for i in range(_dot_hits.size()):
				if _dot_hits[i].has_point(event.position):
					flip(i - _page)
					return

# ── the prop shop — miniature art the vignettes stage (kept here for the file-size split) ──
func _hash(n: float) -> float:   # deterministic 0..1 — the vignettes' only "randomness" (no randf)
	return absf(fposmod(sin(n * 12.9898) * 43758.5453, 1.0))

func _ship(pos: Vector2, ang: float, k: float) -> void:   # the C1 silhouette, compacted (nose -Y)
	var hull := PackedVector2Array([
		Vector2(0, -50), Vector2(8, -38), Vector2(10, -24), Vector2(10, 20), Vector2(8, 32),
		Vector2(0, 38), Vector2(-8, 32), Vector2(-10, 20), Vector2(-10, -24), Vector2(-8, -38),
	])
	draw_set_transform(pos, ang, Vector2.ONE * k)
	draw_colored_polygon(hull, HULL)
	var closed := PackedVector2Array(hull)
	closed.append(hull[0])
	draw_polyline(closed, Color(FOAM.r, FOAM.g, FOAM.b, 0.4), 1.2, true)
	draw_rect(Rect2(-5, -20, 10, 26), DECK)
	draw_rect(Rect2(-3, -30, 6, 8), DECK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _turret(mp: Vector2, a: float, cls: String, forced: bool) -> void:   # class-distinct crib
	var house := Color(0.431, 0.353, 0.314) if forced else Color(0.392, 0.471, 0.522)
	draw_set_transform(mp, a, Vector2.ONE)
	if cls == "L":
		for bx in [-3.2, 3.2]:
			draw_rect(Rect2(bx - 1.3, -31.0, 2.6, 22.0), STEEL)
		draw_rect(Rect2(-8, -10, 16, 20), house)
	elif cls == "M":
		draw_rect(Rect2(-1.1, -20.0, 2.2, 14.0), STEEL)
		draw_rect(Rect2(-5.5, -6.5, 11, 14), house)
	else:
		draw_arc(Vector2.ZERO, 5.5, 0.0, TAU, 16, Color(0.494, 0.576, 0.612), 1.2, true)
		draw_rect(Rect2(-0.55, -13.0, 1.1, 11.0), STEEL)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _gunboat(pos: Vector2, ang: float, k: float) -> void:
	var boat := PackedVector2Array([Vector2(0, -16), Vector2(8, -6), Vector2(8, 12), Vector2(-8, 12), Vector2(-8, -6)])
	draw_set_transform(pos, ang, Vector2.ONE * k)
	draw_colored_polygon(boat, Color(0.118, 0.180, 0.212))
	var bc := PackedVector2Array(boat)
	bc.append(boat[0])
	draw_polyline(bc, Color(RED.r, RED.g, RED.b, 0.8), 1.2, true)
	draw_rect(Rect2(-1.5, -10, 3, 8), RED)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _sub(pos: Vector2, ang: float, alpha: float) -> void:   # the sonar-lit silhouette
	draw_set_transform(pos, ang, Vector2(0.35, 1.0))
	draw_circle(Vector2.ZERO, 20.0, Color(DARK.r, DARK.g, DARK.b, 0.85 * alpha))
	draw_set_transform(pos, ang, Vector2.ONE)
	var pts := PackedVector2Array()
	for i in range(33):
		var a := TAU * i / 32.0
		pts.append(Vector2(cos(a) * 7.0, sin(a) * 20.0))
	draw_polyline(pts, Color(RED.r, RED.g, RED.b, 0.55 * alpha), 1.2, true)
	draw_circle(Vector2(0, -4), 2.4, Color(FOAM.r, FOAM.g, FOAM.b, 0.5 * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _helo(pos: Vector2, ang: float, t: float) -> void:
	var body := Color(0.353, 0.439, 0.478)
	draw_set_transform(pos, ang, Vector2(0.52, 1.0))
	draw_circle(Vector2(0, 1), 6.5, body)
	draw_set_transform(pos, ang, Vector2.ONE)
	draw_rect(Rect2(-1.1, 4, 2.2, 9), body)
	draw_rect(Rect2(-2.6, 12, 5.2, 1.6), STEEL)
	draw_circle(Vector2(0, -2.2), 1.5, Color(FOAM.r, FOAM.g, FOAM.b, 0.75))
	var spin := t * 9.0
	draw_line(Vector2(cos(spin), sin(spin)) * 11.0, Vector2(-cos(spin), -sin(spin)) * 11.0,
		Color(FOAM.r, FOAM.g, FOAM.b, 0.55), 1.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _diamond(p: Vector2, dr: float, col: Color, w: float) -> void:
	draw_polyline(PackedVector2Array([
		p + Vector2(0, -dr), p + Vector2(dr, 0), p + Vector2(0, dr), p + Vector2(-dr, 0), p + Vector2(0, -dr),
	]), col, w, true)

func _dashed_ring(c: Vector2, dr: float, col: Color) -> void:
	for seg in range(36):
		if seg % 2 == 0:
			draw_arc(c, dr, TAU * seg / 36.0, TAU * (seg + 1) / 36.0, 4, col, 1.0, true)

func _splash(p: Vector2, base: float, age: float) -> void:   # mini FxRender column: pop·hang·fall
	if age < 0.0 or age >= 1.6:
		return
	var h := 0.0
	if age < 0.25:
		h = age / 0.25
	elif age < 0.45:
		h = 1.0
	else:
		h = maxf(0.0, 1.0 - pow((age - 0.45) / 0.6, 2.0))
	var grow := 0.8 + 0.5 * minf(age / 0.5, 1.0)
	var fa := 0.5 * (1.0 - age / 1.6)
	draw_circle(p, base * grow, Color(FOAM.r, FOAM.g, FOAM.b, fa * 0.35))
	draw_arc(p, base * grow, 0.0, TAU, 24, Color(FOAM.r, FOAM.g, FOAM.b, fa), 1.2, true)
	if h > 0.02:
		draw_circle(p, base * 0.62 * h, Color(FOAM.r, FOAM.g, FOAM.b, 0.9 * h))
		draw_circle(p + Vector2(-2.0, -3.0) * h, base * 0.4 * h, Color(FOAM.r, FOAM.g, FOAM.b, 0.9 * h))

func _key(p: Vector2, ch: String, lit: bool) -> void:   # ghost-input key glyph
	var kr := Rect2(p.x - 11.0, p.y - 11.0, 22.0, 22.0)
	draw_rect(kr, Color(RED.r, RED.g, RED.b, 0.85) if lit else Color(FOAM.r, FOAM.g, FOAM.b, 0.05))
	draw_rect(kr, BRASS if lit else BRASS_DIM, false, 1.0)
	var w := sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(sans, Vector2(p.x - w * 0.5, p.y + 4.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		FOAM if lit else BRASS_DIM)

func _chip(p: Vector2, label: String, lit: bool) -> void:   # LMB/RMB/MMB order chips
	var cr := Rect2(p.x - 21.0, p.y - 10.0, 42.0, 20.0)
	draw_rect(cr, Color(RED.r, RED.g, RED.b, 0.8) if lit else Color(FOAM.r, FOAM.g, FOAM.b, 0.05))
	draw_rect(cr, BRASS if lit else BRASS_DIM, false, 1.0)
	var w := mono.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(mono, Vector2(p.x - w * 0.5, p.y + 3.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		FOAM if lit else BRASS_DIM)

func _micro(p: Vector2, text: String) -> void:
	draw_string(mono, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8,
		Color(BRASS_DIM.r, BRASS_DIM.g, BRASS_DIM.b, 0.75))

func _reticle(p: Vector2, live: bool) -> void:   # the force-fire cursor, miniaturized
	var col := Color(RED.r, RED.g, RED.b, 0.95) if live else Color(FOAM.r, FOAM.g, FOAM.b, 0.35)
	draw_arc(p, 9.0, 0.0, TAU, 24, col, 1.2, true)
	for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(p + dv * 6.0, p + dv * 12.0, col, 1.2)
