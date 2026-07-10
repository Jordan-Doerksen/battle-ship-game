class_name TitleScreen
extends Control
# The game's front door (C4): propaganda-poster title, commander level + XP bar, BEGIN SORTIE /
# TECH TREE / FIELD MANUAL (C13). Custom-drawn in the plate/brass language; buttons are drawn
# rects with hit tests. Emits signals; Main owns the state machine. Keyboard: ENTER = sortie,
# T = tree, M = manual (Main routes keys).

signal sortie_requested
signal tree_requested
signal manual_requested

const FOAM := Color(0.894, 0.941, 0.949)
const RED := Color(0.851, 0.310, 0.169)
const BRASS := Color(0.804, 0.729, 0.557)
const BRASS_DIM := Color(0.557, 0.506, 0.373)

var _profile: Profile
var _pc: ProgressConfig
var _sans: Font
var _mono: Font
var _btn_sortie := Rect2()
var _btn_tree := Rect2()
var _btn_manual := Rect2()

func bind(profile: Profile, pc: ProgressConfig) -> void:
	_profile = profile
	_pc = pc
	_sans = ThemeDB.fallback_font
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Cascadia Mono", "Menlo", "Consolas", "monospace"])
	_mono = mono
	mouse_filter = Control.MOUSE_FILTER_STOP

func _spaced(cx: float, y: float, text: String, px: int, col: Color, tracking: float) -> void:
	var total := 0.0
	for ch in text:
		total += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking
	var x := cx - total * 0.5
	for ch in text:
		draw_string(_sans, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		x += _sans.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + tracking

func _button(rect: Rect2, label: String, primary: bool) -> void:
	if primary:
		draw_colored_polygon(PackedVector2Array([
			rect.position + Vector2(12, 0), Vector2(rect.end.x, rect.position.y),
			rect.end - Vector2(0, 12), rect.end - Vector2(12, 0),
			Vector2(rect.position.x, rect.end.y), rect.position + Vector2(0, 12),
		]), RED)
	else:
		draw_rect(rect, BRASS_DIM, false, 1.0)
	_spaced(rect.get_center().x, rect.get_center().y + 5.0, label, 15,
		FOAM if primary else BRASS, 4.0)

func _draw() -> void:
	if _profile == null:
		return
	var cx := size.x * 0.5
	var cy := size.y * 0.42
	# C12 play-test: an attract battle runs behind this screen — a quiet scrim keeps the title
	# legible while the war shows around it
	draw_rect(Rect2(cx - 300.0, cy - 140.0, 600.0, 416.0), Color(0.02, 0.078, 0.102, 0.72))
	draw_rect(Rect2(cx - 300.0, cy - 140.0, 600.0, 416.0), Color(0.804, 0.729, 0.557, 0.25), false, 1.0)
	_spaced(cx, cy - 110.0, "★ NAVAL TRIALS BUREAU · RESTRICTED", 10, BRASS_DIM, 3.0)
	_spaced(cx, cy - 62.0, "EARTH", 52, FOAM, 14.0)
	_spaced(cx, cy - 6.0, "DEFENSE FORCE", 52, FOAM, 14.0)
	_spaced(cx, cy + 28.0, "SORTIE COMMAND", 13, RED, 8.0)
	_spaced(cx, cy + 48.0, "THEY CAME FOR OUR WATER. WE ANSWERED WITH THE FLEET.", 9, BRASS_DIM, 2.5)
	# level + XP bar
	var lv: Dictionary = _pc.level_info(_profile.xp)
	var bar := Rect2(cx - 190.0, cy + 86.0, 380.0, 10.0)
	draw_string(_mono, Vector2(bar.position.x, bar.position.y - 8.0),
		"COMMANDER · LEVEL %d" % lv["level"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	var xp_txt := "%d / %d XP" % [lv["into"], lv["next"]]
	draw_string(_mono, Vector2(bar.end.x - _mono.get_string_size(xp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, bar.position.y - 8.0),
		xp_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, BRASS)
	draw_rect(bar, Color(FOAM.r, FOAM.g, FOAM.b, 0.05))
	draw_rect(bar, BRASS_DIM, false, 1.0)
	if lv["next"] > 0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(lv["into"]) / float(lv["next"]), bar.size.y)), RED)
	# buttons — the manual rides a slim third row so the sortie/tree pair keeps its weight (C13)
	_btn_sortie = Rect2(cx - 210.0, cy + 128.0, 220.0, 48.0)
	_btn_tree = Rect2(cx + 30.0, cy + 128.0, 180.0, 48.0)
	_btn_manual = Rect2(cx - 120.0, cy + 190.0, 240.0, 36.0)
	_button(_btn_sortie, "BEGIN SORTIE", true)
	_button(_btn_tree, "TECH TREE", false)
	_button(_btn_manual, "FIELD MANUAL", false)
	_spaced(cx, cy + 252.0, "ENTER — SORTIE     T — TECH TREE     M — MANUAL", 9, BRASS_DIM, 2.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _btn_sortie.has_point(event.position):
			sortie_requested.emit()
		elif _btn_tree.has_point(event.position):
			tree_requested.emit()
		elif _btn_manual.has_point(event.position):
			manual_requested.emit()
