class_name RadioPanel
extends RefCounted
# THE FLEET RADIO teletype (top-right) — TF50 ACTUAL's rolling comms log. Absorbs and replaces the
# C12 single advisory plate. Static draw func called by HelmGauges._draw (the C9 render-domain split
# pattern: all state lives on the host, reached via `g.`). Reads g.radio_lines (RadioComms.
# display_lines()); the NEWEST line types out character-by-character, older lines dim.
#
# FIXED 300×92 box anchored to the right edge (x = size.x − PAD − 300, y = PAD) — clear of the wave
# plate (top-left), the boss plate (top-center) and the scope (bottom-right). Lines are clipped to
# the panel width so the plate NEVER reflows (the reserve-max-height house rule): three bottom-aligned
# rows, the newest at the bottom like a comms feed.

const PW := 300.0
const PH := 92.0
const MARGIN := 14.0    # inner left/right padding
const LINE_PX := 11     # log-line font size
const ROW_STEP := 19.0  # baseline spacing between rows

static func draw(g: HelmGauges) -> void:
	var ox: float = g.size.x - HelmGauges.PAD - PW
	var oy: float = HelmGauges.PAD
	g._draw_plate(Vector2(ox, oy), Vector2(PW, PH))
	var x: float = ox + MARGIN
	g._label(x, oy + 20.0, "◤ TF50 ACTUAL")   # callsign header, brass-dim (the panel prefixes nothing else)
	var max_w: float = PW - MARGIN * 2.0
	var lines: Array = g.radio_lines
	var n: int = mini(lines.size(), 3)
	var now: int = Time.get_ticks_msec()
	for i in range(n):
		var entry: Dictionary = lines[lines.size() - n + i]   # keep only the last 3, in order
		var row: int = 3 - n + i                              # bottom-align: newest sits on the bottom row
		var base_y: float = oy + 40.0 + float(row) * ROW_STEP
		var display: String = RadioPanel._fit(g, String(entry["text"]), max_w)
		var reveal: float = float(entry["reveal"])
		var newest: bool = bool(entry["newest"])
		var visible: int = clampi(int(ceil(reveal * float(display.length()))), 0, display.length())
		var shown: String = display.substr(0, visible)
		var col: Color = HelmGauges.FOAM if newest else Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.5)
		g.draw_string(g._mono, Vector2(x, base_y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_PX, col)
		# a soft blinking caret while the newest line is still coming in over the net
		if newest and reveal < 1.0 and (now / 320) % 2 == 0:
			var cx: float = x + g._mono.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_PX).x + 1.0
			g.draw_rect(Rect2(cx, base_y - 8.0, 4.0, 9.0), Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.6))

# Clip a line to the panel width with a trailing ellipsis so the plate never reflows (house rule).
static func _fit(g: HelmGauges, text: String, max_w: float) -> String:
	if g._mono.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_PX).x <= max_w:
		return text
	var ell := "…"
	var s := text
	while s.length() > 1 and g._mono.get_string_size(s + ell, HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_PX).x > max_w:
		s = s.substr(0, s.length() - 1)
	return s + ell
