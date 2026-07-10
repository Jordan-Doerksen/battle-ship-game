class_name HudOverlays
extends RefCounted
# Full-screen / cursor overlays — the SHIP LOST card (+ its misclick guard), the PAUSED plate, the
# advisory plate, and the force-fire reticle (flight time, MAX RANGE telltale, the RANGEKEEPER
# ghost). Static draw funcs called by HelmGauges._draw; all state lives on the host (the C9
# render-domain split pattern). draw_lost_card reads/writes g._lost_shown_ms.

# ── SHIP LOST card (C3 + C4 XP report; C12 misclick guard — the card holds 1.5 s, a quiet
#    "…" where the prompt goes, then the key-only restart line reveals. Main ignores clicks;
#    this side only paints the hold.) ──
static func draw_lost_card(g: HelmGauges) -> void:
	if g._lost_shown_ms < 0:
		g._lost_shown_ms = Time.get_ticks_msec()
	g.draw_rect(Rect2(Vector2.ZERO, g.size), Color(0.08, 0.024, 0.016, 0.55))
	var cw := 460.0
	var chh := 176.0
	var origin := Vector2((g.size.x - cw) * 0.5, (g.size.y - chh) * 0.5)
	var pts := PackedVector2Array([
		origin + Vector2(14, 0), origin + Vector2(cw, 0), origin + Vector2(cw, chh - 14),
		origin + Vector2(cw - 14, chh), origin + Vector2(0, chh), origin + Vector2(0, 14),
	])
	g.draw_colored_polygon(pts, HelmGauges.PLATE_BG)
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	g.draw_polyline(closed, HelmGauges.RED, 1.2, true)
	var cxr := origin.x + cw * 0.5
	g._centered_spaced(cxr, origin.y + 52.0, "SHIP LOST", 30, HelmGauges.RED, 8.0)
	var stats := "WAVE %d · %d DRONES DESTROYED" % [g._world.wave, g._world.kills]
	g.draw_string(g._mono, Vector2(cxr - g._mono.get_string_size(stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x * 0.5, origin.y + 90.0),
		stats, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, HelmGauges.FOAM)
	var xp_line := "+%d XP" % int(g.lost_report.get("xp", g._world.xp_run))
	if int(g.lost_report.get("leveled_to", 0)) > 0:
		xp_line += " · LEVEL UP → %d" % int(g.lost_report["leveled_to"])
	g.draw_string(g._mono, Vector2(cxr - g._mono.get_string_size(xp_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, origin.y + 116.0),
		xp_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, HelmGauges.BRASS)
	if Time.get_ticks_msec() - g._lost_shown_ms < HelmGauges.LOST_GUARD_MS:
		g._centered_spaced(cxr, origin.y + 150.0, "…", 11, Color(HelmGauges.BRASS.r, HelmGauges.BRASS.g, HelmGauges.BRASS.b, 0.55), 3.0)
	else:
		g._centered_spaced(cxr, origin.y + 150.0, "R — NEW SORTIE · T — THE TREE", 11, HelmGauges.BRASS, 3.0)

# ── C12 PAUSED plate — the sim holds; the sea keeps drifting on the render clock by design ──
static func draw_pause(g: HelmGauges) -> void:
	var pw := 340.0
	var ph := 96.0
	var origin := Vector2((g.size.x - pw) * 0.5, (g.size.y - ph) * 0.5)
	g._draw_plate(origin, Vector2(pw, ph))
	var cx := origin.x + pw * 0.5
	g._centered_spaced(cx, origin.y + 40.0, "PAUSED", 22, HelmGauges.FOAM, 7.0)
	var sub := "The war waits. The sea doesn't."
	g.draw_string(g._mono, Vector2(cx - g._mono.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5, origin.y + 62.0),
		sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HelmGauges.BRASS)
	g._centered_spaced(cx, origin.y + 82.0, "P — RESUME", 8, HelmGauges.BRASS_DIM, 2.5)

# ── C12 advisory plate — the contextual-drip onboarding line. Main decides WHAT and WHEN
#    (once per profile); this side only paints. FIXED 560×54 whatever the text — the UI never
#    reflows (house rule). Deadpan; no border flash. Sits below the boss-plate zone (ends y 88). ──
static func draw_hint(g: HelmGauges) -> void:
	var pw := 560.0
	var ph := 54.0
	var origin := Vector2((g.size.x - pw) * 0.5, 96.0)
	g._draw_plate(origin, Vector2(pw, ph))
	var cx := origin.x + pw * 0.5
	g._centered_spaced(cx, origin.y + 20.0, "ADVISORY", 9, HelmGauges.BRASS_DIM, 2.5)
	g.draw_string(g._mono, Vector2(cx - g._mono.get_string_size(g.hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5, origin.y + 40.0),
		g.hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, HelmGauges.FOAM)

# ── force-fire reticle (+ C11: flight time, the MAX RANGE telltale, the RANGEKEEPER ghost) ──
static func draw_reticle(g: HelmGauges) -> void:
	var mp := g.get_viewport().get_mouse_position()
	var label := g._order_label()
	var col := Color(HelmGauges.RED.r, HelmGauges.RED.g, HelmGauges.RED.b, 0.95) if label != "" else Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.35)
	var r: float = 14.0 if label != "" else 9.0
	g.draw_arc(mp, r, 0.0, TAU, 32, col, 1.4, true)
	for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		g.draw_line(mp + dv * (r - 4.0), mp + dv * (r + 5.0), col, 1.4)
	if label != "":
		g.draw_string(g._sans, mp + Vector2(18, -12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)
	# C11: while the MAIN battery is ordered, the reticle reads the shot — flight time to the
	# burst point, or the mode telltale when the cursor is past reach (the C3 bearing shot).
	if g._world.input.force_all or g._world.input.force_large:
		var mb: WeaponDef = g._cfgs.weapons.by_id("mb16")
		if mb != null:
			var origin: Vector2 = HudOverlays._nearest_l_mount(g, g._world.input.aim_world)
			var dist: float = origin.distance_to(g._world.input.aim_world)
			var line: String = "%.1f s · %d u" % [dist / mb.speed, int(dist)] if dist <= mb.range_u \
				else "MAX RANGE · BEARING"
			g.draw_string(g._mono, mp + Vector2(-34, 28), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(HelmGauges.FOAM.r, HelmGauges.FOAM.g, HelmGauges.FOAM.b, 0.85))
			HudOverlays._draw_rangekeeper(g, mb, origin)

# C11 ord7 — the plotting room advises: a ghost diamond at the computed intercept for the surface
# contact nearest the cursor (within the snap radius). Advisory only: shells obey the cursor.
# HUD-side one-way read; enemy velocity derived exactly as Turrets leads (heading × def speed).
static func _draw_rangekeeper(g: HelmGauges, mb: WeaponDef, origin: Vector2) -> void:
	if not g._cfgs.tech.rangekeeper:
		return
	var best: Enemy = null
	var bd: float = g._cfgs.tech.rangekeeper_snap
	for e in g._world.enemies:
		if not e.active or e.layer != "surf":
			continue
		var d: float = e.pos.distance_to(g._world.input.aim_world)
		if d <= bd:
			bd = d
			best = e
	if best == null:
		return
	var tdef: EnemyDef = g._cfgs.enemies.by_id(best.type_id)
	var tvel := Vector2(sin(best.heading), -cos(best.heading)) * (tdef.speed if tdef != null else 0.0)
	var cap: float = mb.range_u / mb.speed
	var t: float = minf(origin.distance_to(best.pos) / mb.speed, cap)
	var ghost: Vector2 = best.pos + tvel * t
	t = minf(origin.distance_to(ghost) / mb.speed, cap)
	ghost = best.pos + tvel * t
	var cam := g.get_viewport().get_camera_2d()
	var zoom: float = cam.zoom.x if cam != null else 1.0
	var half: Vector2 = g.get_viewport_rect().size * 0.5
	var gs: Vector2 = (ghost - g._world.ship_pos) * zoom + half
	var ts: Vector2 = (best.pos - g._world.ship_pos) * zoom + half
	g.draw_line(ts, gs, Color(HelmGauges.STEEL.r, HelmGauges.STEEL.g, HelmGauges.STEEL.b, 0.5), 1.0)
	var dia := PackedVector2Array([
		gs + Vector2(0, -6), gs + Vector2(6, 0), gs + Vector2(0, 6), gs + Vector2(-6, 0), gs + Vector2(0, -6),
	])
	g.draw_polyline(dia, Color(HelmGauges.STEEL.r, HelmGauges.STEEL.g, HelmGauges.STEEL.b, 0.9), 1.4, true)
	g.draw_string(g._mono, gs + Vector2(9, -6), "RK", HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
		Color(HelmGauges.STEEL.r, HelmGauges.STEEL.g, HelmGauges.STEEL.b, 0.8))

static func _nearest_l_mount(g: HelmGauges, pt: Vector2) -> Vector2:
	var hp: HardpointConfig = g._cfgs.hardpoints
	var best: Vector2 = g._world.ship_pos
	var bd: float = INF
	for i in range(hp.mount_pos.size()):
		if hp.mount_size[i] != "L":
			continue
		var mpos: Vector2 = Turrets.mount_world(g._world, hp.mount_pos[i])
		var d: float = mpos.distance_to(pt)
		if d < bd:
			bd = d
			best = mpos
	return best
