class_name TerrainRender
extends RefCounted
# C15 THE WATERS — the terrain art layer, ported faithfully from design/the-waters.html (the
# APPROVED mockup; gate PASSED 2026-07-10). Each sim terrain circle ({ pos, r, islet } — the
# collision TRUTH, owned by the sim) grows a cosmetic body here, coast-out: (a) a pale SHOAL
# HALO fading to nothing at SHOAL_SCALE × r (the mockup's radial gradient approximated with
# three stacked alpha steps — _draw has no gradients); (b) two breathing FOAM FRINGE rings
# hugging the coastline (splash-disc foam language, slow pulse on the render sea clock; static
# under reduced motion but KEPT — they chart where the coast is); (c) a wobbled basalt BODY
# with a darker heart + facet relief lines — warm dark grays, emphatically NOT hostile-red,
# NOT ship-steel; (d) deadpan props on islets only — a scrubby bush or a lone brass nav light
# on a slow blink. All wobble comes from a DETERMINISTIC hash off world.world_seed (cosmetic,
# like the flecks — never world.rng, D1.4); the art is built once and cached on the renderer
# (_terrain_art), rebuilt when world.terrain changes size, cleared in bind(). Small rocks ride
# the size_floor ART boost so a 10 u reef still reads at 0.4 zoom — the sim circle stays
# honest at world size. House pattern: static funcs taking the FieldRenderer.

const SHOAL_SCALE := 1.54   # shoal halo extent × feature r — the owner's gate tune of 2026-07-10
                            # (was ~1.5 in the mockup default); THE dial for future shoal tuning

const SHOAL := Color(0.290, 0.502, 0.471)         # pale shallow sea-green (mockup 74,128,120)
const ISLET_BODY := Color(0.290, 0.267, 0.227)    # #4A443A — warm dark basalt
const ROCK_BODY := Color(0.247, 0.227, 0.196)     # #3F3A32 — the reefs run a shade darker
const COAST := Color(0.059, 0.051, 0.039, 0.55)   # coastline stroke
const CORE := Color(0.086, 0.075, 0.059, 0.30)    # the darker heart — cheap relief
const FACET := Color(0.063, 0.055, 0.043, 0.5)    # relief facet lines
const BUSH := Color(0.184, 0.290, 0.200)          # #2F4A33 — scrub green
const BRASS := Color(0.804, 0.729, 0.557)         # #CDBA8E — the nav light

# ── deterministic cosmetic hash: world seed × feature index × salt → [0, 1) ──
static func _hf(seed_v: int, fi: int, salt: int) -> float:
	var x: int = seed_v + fi * 374761393 + salt * 668265263
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return float(x & 0xFFFFFF) / 16777216.0

# Raw wobbled coast verts (LOCAL offsets): 9–12 points at r × (0.85 + 0.3 × hash), angle-jittered.
# Shared with HelmGauges' scope land so the chart and the world agree on every coastline.
static func verts_local(seed_v: int, fi: int, radius: float) -> PackedVector2Array:
	var n: int = 9 + int(_hf(seed_v, fi, 999) * 3.999)
	var pts := PackedVector2Array()
	for vi in range(n):
		var a: float = (float(vi) / float(n)) * TAU + (_hf(seed_v, fi, 100 + vi) - 0.5) * (TAU / float(n)) * 0.6
		var rad: float = radius * (0.85 + 0.3 * _hf(seed_v, fi, vi))
		pts.append(Vector2(sin(a) * rad, -cos(a) * rad))
	return pts

# Smoothed coast — quadratics through edge midpoints (the mockup's traceBlob), 3 sub-segments each.
static func _smooth(raw: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = raw.size()
	for si in range(n):
		var m0: Vector2 = (raw[(si + n - 1) % n] + raw[si]) * 0.5
		var m1: Vector2 = (raw[si] + raw[(si + 1) % n]) * 0.5
		for st in range(1, 4):
			var t: float = float(st) / 3.0
			var qa: Vector2 = m0.lerp(raw[si], t)
			var qb: Vector2 = raw[si].lerp(m1, t)
			out.append(qa.lerp(qb, t))
	return out

# Build the per-feature cosmetic art once (terrain is static) — coast, facets, props, phase.
static func _build_art(r: FieldRenderer, terr: Array) -> void:
	var sv: int = r._world.world_seed
	r._terrain_art.clear()
	for fi in range(terr.size()):
		var f: Dictionary = terr[fi]
		var raw: PackedVector2Array = verts_local(sv, fi, f["r"])
		var facets: Array = []   # coast-toward-heart relief lines, 2–3 per body
		var nf: int = 2 + (1 if _hf(sv, fi, 200) < 0.5 else 0)
		for fj in range(nf):
			var cpick: Vector2 = raw[int(_hf(sv, fi, 210 + fj) * raw.size()) % raw.size()]
			var ia: float = _hf(sv, fi, 230 + fj) * TAU
			var idist: float = f["r"] * (0.10 + 0.30 * _hf(sv, fi, 250 + fj))
			facets.append([cpick * 0.82, Vector2(sin(ia), -cos(ia)) * idist])
		var props: Array = []    # 1–2 deadpan props, islets only — deterministic pick per slot
		if f["islet"]:
			var np: int = 1 + (1 if _hf(sv, fi, 300) < 0.5 else 0)
			for pi in range(np):
				var pa: float = _hf(sv, fi, 320 + pi) * TAU
				var pd: float = f["r"] * (0.28 + 0.32 * _hf(sv, fi, 330 + pi))
				var dots: Array = []   # bush dot scatter, fixed at build time
				for di in range(4):
					dots.append(Vector2((_hf(sv, fi, 340 + pi * 8 + di) * 2.0 - 1.0) * 6.0,
						(_hf(sv, fi, 380 + pi * 8 + di) * 2.0 - 1.0) * 6.0))
				props.append({
					"type": "bush" if _hf(sv, fi, 310 + pi) < 0.55 else "light",
					"off": Vector2(sin(pa), -cos(pa)) * pd,
					"ph": _hf(sv, fi, 360 + pi) * TAU, "dots": dots,
				})
		r._terrain_art.append({ "coast": _smooth(raw), "facets": facets, "props": props,
			"ph": _hf(sv, fi, 400) * TAU })

# ── the layer — world coordinates, between the wake and the war ──
static func draw(r: FieldRenderer) -> void:
	# .get() guard (annotated workaround): worlds predating world.terrain — old saves, probe
	# worlds, boots before the C15 sim lands the field — return null here, and the whole layer
	# no-ops cleanly instead of erroring on a missing property.
	var terr: Variant = r._world.get("terrain")
	if not (terr is Array) or terr.is_empty():
		return
	if r._terrain_art.size() != terr.size():
		_build_art(r, terr)
	var view: Rect2 = r.view_rect()
	var reduced: bool = r._field_cfg.reduced_motion
	for ti in range(terr.size()):
		var f: Dictionary = terr[ti]
		var pos: Vector2 = f["pos"]
		var boost: float = r.size_floor(f["r"] * 2.0)   # ART floor only — the sim circle stays honest
		if not view.grow(f["r"] * boost * SHOAL_SCALE + 60.0).has_point(pos):
			continue
		var art: Dictionary = r._terrain_art[ti]
		# (a) SHOAL HALO — under everything; three stacked steps approximate the mockup gradient
		var ro: float = f["r"] * boost * SHOAL_SCALE
		r.draw_circle(pos, ro, Color(SHOAL.r, SHOAL.g, SHOAL.b, 0.08))
		r.draw_circle(pos, ro * 0.72, Color(SHOAL.r, SHOAL.g, SHOAL.b, 0.10))
		r.draw_circle(pos, ro * 0.45, Color(SHOAL.r, SHOAL.g, SHOAL.b, 0.12))
		# (b) FOAM FRINGE — two coast-hugging rings breathing on the sea clock
		var pulse: float = 0.0 if reduced else sin(r.sea_t * 0.7 + art["ph"] + pos.x * 0.013)
		var coast: PackedVector2Array = art["coast"]
		_ring(r, pos, coast, boost * (1.05 + 0.013 * pulse),
			Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.30 + 0.10 * pulse),
			maxf(r.lw(1.6), 1.2))
		_ring(r, pos, coast, boost * (1.16 + 0.025 * pulse),
			Color(FieldRenderer.FOAM.r, FieldRenderer.FOAM.g, FieldRenderer.FOAM.b, 0.13 + 0.05 * pulse),
			maxf(r.lw(1.1), 1.0))
		# (c) the BODY — basalt fill, coast stroke, darker heart, facet relief
		var poly := PackedVector2Array()
		for cpt in coast:
			poly.append(pos + cpt * boost)
		r.draw_colored_polygon(poly, ISLET_BODY if f["islet"] else ROCK_BODY)
		var closed := PackedVector2Array(poly)
		closed.append(poly[0])
		r.draw_polyline(closed, COAST, maxf(r.lw(1.2), 1.0), true)
		var heart := PackedVector2Array()
		for hpt in coast:
			heart.append(pos + hpt * boost * 0.52)
		r.draw_colored_polygon(heart, CORE)
		for fc in art["facets"]:
			r.draw_line(pos + fc[0] * boost, pos + fc[1] * boost, FACET, maxf(r.lw(1.0), 0.8))
		# (d) deadpan props — islets only
		for pr in art["props"]:
			_draw_prop(r, pos + pr["off"] * boost, pr, reduced)

static func _ring(r: FieldRenderer, pos: Vector2, coast: PackedVector2Array, s: float, col: Color, w: float) -> void:
	if col.a <= 0.01:
		return
	var pts := PackedVector2Array()
	for rp in coast:
		pts.append(pos + rp * s)
	pts.append(pts[0])
	r.draw_polyline(pts, col, w, true)

static func _draw_prop(r: FieldRenderer, ppos: Vector2, pr: Dictionary, reduced: bool) -> void:
	var z: float = r.zoom()
	if pr["type"] == "bush":   # scrubby bush — a dark-green dot cluster
		for dv in pr["dots"]:
			r.draw_circle(ppos + dv, maxf(2.4, 1.4 / z), BUSH)
	else:                      # the lone navigation light, blinking slowly (steady under reduced motion)
		var lit: bool = true if reduced else fmod(r.sea_t * 0.45 + pr["ph"], 3.0) < 0.4
		var rr: float = maxf(2.0, 1.6 / z)
		if lit and not reduced:   # soft brass halo on the flash
			r.draw_circle(ppos, rr * 3.0, Color(BRASS.r, BRASS.g, BRASS.b, 0.22))
		r.draw_circle(ppos, rr, Color(BRASS.r, BRASS.g, BRASS.b, 0.7 if reduced else (1.0 if lit else 0.28)))
