class_name TechTreeScreen
extends Control
# The tech tree plotting board (C4, mockup-matched; C5 adds the SONAR column): header with
# level/points/XP/respec/back, six branch columns of nodes, strict in-branch order, variable
# costs, AIR WING redacted + CLASSIFIED.
# Custom-drawn with hit-tested rects; purchases go through Tech.can_buy and save immediately.

signal back_requested

const FOAM := Color(0.894, 0.941, 0.949)
const RED := Color(0.851, 0.310, 0.169)
const BRASS := Color(0.804, 0.729, 0.557)
const BRASS_DIM := Color(0.557, 0.506, 0.373)
const PLATE_BG := Color(0.051, 0.125, 0.157, 0.88)
const PLATE_EDGE := Color(0.804, 0.729, 0.557, 0.5)

const BRANCHES := ["SEAMANSHIP", "FLAK", "GUNNERY", "ORDNANCE", "SONAR", "AIR WING"]
const SUBTITLES := {
	"SEAMANSHIP": "movement & hull", "FLAK": "small mounts", "GUNNERY": "medium mounts",
	"ORDNANCE": "main battery", "SONAR": "hydrophones & racks", "AIR WING": "helicopter operations",
}

var _profile: Profile
var _tech: TechConfig
var _pc: ProgressConfig
var _sans: Font
var _mono: Font
var _node_hits: Array = []      # { rect: Rect2, id: String }
var _btn_respec := Rect2()
var _btn_back := Rect2()

func bind(profile: Profile, tech: TechConfig, pc: ProgressConfig) -> void:
	_profile = profile
	_tech = tech
	_pc = pc
	_sans = ThemeDB.fallback_font
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Cascadia Mono", "Menlo", "Consolas", "monospace"])
	_mono = mono
	mouse_filter = Control.MOUSE_FILTER_STOP

func _label(x: float, y: float, text: String, px: int, col: Color, tracking: float) -> float:
	var cx := x
	for ch in text:
		draw_string(_sans, Vector2(cx, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		cx += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking
	return cx

func _draw() -> void:
	if _profile == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.016, 0.055, 0.075, 0.55))
	_node_hits.clear()
	var margin := 30.0
	var wmax: float = minf(size.x - margin * 2.0, 1360.0)   # six columns (C5)
	var left: float = (size.x - wmax) * 0.5
	# ── header ──
	var head := Rect2(left, 24.0, wmax, 54.0)
	draw_rect(head, PLATE_BG)
	draw_rect(head, PLATE_EDGE, false, 1.0)
	var lv: Dictionary = _pc.level_info(_profile.xp)
	var pts: int = Tech.points_available(_profile, _tech, _pc)
	var hx := head.position.x + 18.0
	var hy := head.get_center().y + 5.0
	draw_string(_mono, Vector2(hx, hy), "LEVEL %d" % lv["level"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, FOAM)
	draw_string(_mono, Vector2(hx + 110.0, hy), "POINTS:", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, FOAM)
	draw_string(_mono, Vector2(hx + 186.0, hy), str(pts), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, RED)
	var bar := Rect2(hx + 230.0, head.get_center().y - 5.0, wmax - 640.0, 10.0)
	draw_rect(bar, Color(FOAM.r, FOAM.g, FOAM.b, 0.05))
	draw_rect(bar, BRASS_DIM, false, 1.0)
	if lv["next"] > 0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(lv["into"]) / float(lv["next"]), bar.size.y)), RED)
	var xp_txt := "%d / %d" % [lv["into"], lv["next"]]
	draw_string(_mono, Vector2(bar.end.x + 12.0, hy), xp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	_btn_respec = Rect2(head.end.x - 210.0, head.position.y + 11.0, 96.0, 32.0)
	_btn_back = Rect2(head.end.x - 102.0, head.position.y + 11.0, 88.0, 32.0)
	draw_rect(_btn_respec, BRASS_DIM, false, 1.0)
	_label(_btn_respec.position.x + 16.0, _btn_respec.get_center().y + 4.0, "RESPEC", 11, BRASS, 2.5)
	draw_rect(_btn_back, RED)
	_label(_btn_back.position.x + 20.0, _btn_back.get_center().y + 4.0, "TITLE", 11, FOAM, 2.5)
	# ── branch columns ──
	var col_w: float = (wmax - 5.0 * 12.0) / 6.0
	for b in range(BRANCHES.size()):
		var br: String = BRANCHES[b]
		var cx: float = left + b * (col_w + 12.0)
		var cy: float = 92.0
		# C6: buying WHIRLYBIRD declassifies the program — until then only air1 shows its face
		var classified: bool = br == "AIR WING" and not _profile.unlocked.has("air1")
		var nodes: Array = []
		for n in _tech.catalog:
			if n.branch == br:
				nodes.append(n)
		var col_h: float = 46.0 + nodes.size() * 68.0 + (34.0 if classified else 6.0)
		draw_rect(Rect2(cx, cy, col_w, col_h), Color(0.051, 0.125, 0.157, 0.75))
		draw_rect(Rect2(cx, cy, col_w, col_h), Color(0.804, 0.729, 0.557, 0.25), false, 1.0)
		_label(cx + 10.0, cy + 20.0, br, 12, FOAM, 2.5)
		draw_string(_sans, Vector2(cx + 10.0, cy + 34.0), SUBTITLES[br], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, BRASS_DIM)
		var ny: float = cy + 44.0
		for n in nodes:
			var r := Rect2(cx + 8.0, ny, col_w - 16.0, 60.0)
			var owned: bool = _profile.unlocked.has(n.id)
			var buyable: bool = Tech.can_buy(_profile, n.id, _tech, _pc)
			# C6: air2+ stay REDACTED until WHIRLYBIRD is owned; air1 itself is a normal buy
			var redacted: bool = classified and n.id != "air1"
			var alpha: float = 0.45 if (redacted or (not owned and not buyable)) else 1.0
			if owned:
				draw_rect(r, Color(RED.r, RED.g, RED.b, 0.12))
			else:
				draw_rect(r, Color(FOAM.r, FOAM.g, FOAM.b, 0.03))
			draw_rect(r, Color(RED.r, RED.g, RED.b, alpha) if owned else Color(BRASS_DIM.r, BRASS_DIM.g, BRASS_DIM.b, alpha), false, 1.0)
			var nm: String = "████████" if redacted else n.display_name.to_upper()
			var ds: String = "CLEARANCE: FLIGHT CREW ONLY" if redacted else n.desc
			var name_col: Color = FOAM if owned else (RED if n.marquee and not redacted else BRASS)
			name_col.a = alpha
			draw_string(_sans, Vector2(r.position.x + 8.0, r.position.y + 18.0),
				nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, name_col)
			var desc_col := Color(BRASS_DIM.r, BRASS_DIM.g, BRASS_DIM.b, alpha)
			draw_string(_mono, Vector2(r.position.x + 8.0, r.position.y + 36.0),
				ds.left(34), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, desc_col)
			if ds.length() > 34:
				draw_string(_mono, Vector2(r.position.x + 8.0, r.position.y + 48.0),
					ds.substr(34, 34), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, desc_col)
			if not n.locked and not redacted:
				var ct := "OWNED" if owned else "%d PT" % n.cost
				var cc: Color = RED if owned else BRASS_DIM
				draw_string(_mono, Vector2(r.end.x - _mono.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x - 6.0, r.position.y + 14.0),
					ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, cc)
				_node_hits.append({ "rect": r, "id": n.id })
			elif redacted:
				draw_string(_mono, Vector2(r.end.x - _mono.get_string_size("█ PT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x - 6.0, r.position.y + 14.0),
					"█ PT", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(BRASS_DIM.r, BRASS_DIM.g, BRASS_DIM.b, alpha))
			ny += 68.0
		if classified:   # the stamp
			draw_set_transform(Vector2(cx + col_w * 0.5, ny + 10.0), -0.07, Vector2.ONE)
			var sr := Rect2(-70.0, -12.0, 140.0, 26.0)
			draw_rect(sr, Color(RED.r, RED.g, RED.b, 0.65), false, 2.0)
			_label(-56.0, 7.0, "CLASSIFIED", 11, Color(RED.r, RED.g, RED.b, 0.85), 3.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _btn_back.has_point(event.position):
		back_requested.emit()
		return
	if _btn_respec.has_point(event.position):
		_profile.respec()
		queue_redraw()
		return
	for h in _node_hits:
		if h["rect"].has_point(event.position):
			if Tech.can_buy(_profile, h["id"], _tech, _pc):
				_profile.unlocked.append(h["id"])
				_profile.save()
				queue_redraw()
			return
