class_name Terrain
extends RefCounted
# C15 THE WATERS (design/the-waters.html mockup gate; land rules in DECISIONS.md's Change Log,
# 2026-07-10). Static waters: rocks + islets seeded ONCE per world — Main calls generate() right
# after creating each real world, before its first step, and never again. Worlds that never call
# it (every pre-C15 probe) are OPEN WATER: each query below no-ops on the empty array, so the sim
# steps byte-identical to pre-C15 there. Features are the SIM collision circles
# ({ "pos": Vector2, "r": float, "islet": bool }); the renderer dresses the same records
# (wobbled coasts, shoals, props) cosmetically — the circles are the only physics truth.

# Seeded generation — draws ONLY from world.rng, in one stable order: islet count, rock count,
# then per feature its radius followed by rejection-sampled positions.
static func generate(world: GameWorld, cfg: Configs) -> void:
	var tc: TerrainConfig = cfg.terrain
	world.terrain.clear()
	var n_islet: int = world.rng.rand_int(tc.islet_min, tc.islet_max)
	var n_rock: int = world.rng.rand_int(tc.rock_min, tc.rock_max)
	for i in range(n_islet):
		_place(world, tc, world.rng.rangef(tc.islet_r_min, tc.islet_r_max) * tc.size_scale, true)
	for j in range(n_rock):
		_place(world, tc, world.rng.rangef(tc.rock_r_min, tc.rock_r_max) * tc.size_scale, false)

# Rejection-sample one feature, honoring the ship-start clearing (she launches at the origin) and
# the min edge-to-edge channel. Attempts are CAPPED: a crowded seed skips the feature — fewer
# features, still deterministic, never an infinite loop.
static func _place(world: GameWorld, tc: TerrainConfig, r: float, islet: bool) -> void:
	for attempt in range(40):
		var p := Vector2(world.rng.rangef(-tc.field_extent, tc.field_extent),
			world.rng.rangef(-tc.field_extent, tc.field_extent))
		if p.length() - r < tc.start_clear:
			continue
		var ok: bool = true
		for f in world.terrain:
			if p.distance_to(f["pos"]) - r - f["r"] < tc.gap_min:
				ok = false
				break
		if ok:
			world.terrain.append({ "pos": p, "r": r, "islet": islet })
			return

# Point-in-land test (spawn duds, probe law checks).
static func blocked(world: GameWorld, p: Vector2) -> bool:
	for f in world.terrain:
		if p.distance_to(f["pos"]) <= f["r"]:
			return true
	return false

# True when p keeps at least `pad` of open water from every feature edge (spawn placement).
static func clear_of(world: GameWorld, p: Vector2, pad: float) -> bool:
	for f in world.terrain:
		if p.distance_to(f["pos"]) <= f["r"] + pad:
			return false
	return true

# Cheap segment-vs-circles sweep for stepping projectiles: the FIRST contact point along
# from→to, or Vector2.INF when the leg crosses nothing (compare `.x != INF`).
static func hit(world: GameWorld, from: Vector2, to: Vector2) -> Vector2:
	if world.terrain.is_empty():
		return Vector2.INF
	var d: Vector2 = to - from
	var len2: float = d.length_squared()
	var best_t: float = INF
	for f in world.terrain:
		var m: Vector2 = from - f["pos"]
		var r: float = f["r"]
		if len2 <= 1e-9:
			if m.length() <= r:
				best_t = 0.0
			continue
		var c: float = m.length_squared() - r * r
		if c <= 0.0:   # the leg STARTS inside — contact is immediate, nothing can be earlier
			best_t = 0.0
			break
		var b: float = m.dot(d)
		var disc: float = b * b - len2 * c
		if disc < 0.0:
			continue
		var t: float = (-b - sqrt(disc)) / len2
		if t >= 0.0 and t <= 1.0 and t < best_t:
			best_t = t
	if best_t == INF:
		return Vector2.INF
	return from + d * best_t

# Hard safety for waterborne AI hulls: if a center somehow ends up within `pad` of a feature,
# shove it radially back to open water. Pure arithmetic, no rng; no-op on open water.
static func push_out(world: GameWorld, p: Vector2, pad: float) -> Vector2:
	for f in world.terrain:
		var away: Vector2 = p - f["pos"]
		var d: float = away.length()
		if d < f["r"] + pad:
			if d < 1e-3:   # dead center — pick a stable, deterministic escape axis
				away = Vector2(1.0, 0.0)
				d = 1.0
			p = f["pos"] + (away / d) * (f["r"] + pad)
	return p

# Tangent avoidance, ported from the mockup (shared by gunboats, subs, and waterborne machines).
# If the forward ray passes within (feature r + clear) of a feature inside `look`, answer the
# heading that grazes the tangent; INF = channel clear, keep your own desired heading.
#
# MOCKUP FIX 1 — the tangent SIDE is STICKY per agent: with a feature dead ahead the raw side
# flips sign every frame, the two turn orders cancel, and the helmsman motors straight into the
# rock and parks (the mockup's headless probe caught boats stalled 40 s at a time). Once committed
# to a feature, keep rounding the same way until it clears the ray.
# Sticky memory rides Object metadata ("av_f" feature index / "av_s" side) — a deliberate
# workaround: Enemy.gd/Boss.gd are plain-data entity files owned outside this chunk, and meta
# keeps C15's per-agent state inside the terrain system without growing them. No rng, replay-safe.
#
# MOCKUP FIX 2 — outside the clearance ring the capped asin grazes the tangent, but INSIDE the
# ring it points slightly inward and becomes a stable limit cycle (the mockup probe caught a
# gunboat doing donuts around an islet forever). Inside, steer OUTWARD-tangential (>90° off the
# feature bearing) so the helmsman spirals back out of the ring, then the normal tangent resumes.
static func avoid_heading(world: GameWorld, pos: Vector2, heading: float, look: float,
		clear: float, agent: Object) -> float:
	if world.terrain.is_empty():
		return INF
	var d := Vector2(sin(heading), -cos(heading))
	var hit_i: int = -1
	var hit_t: float = INF
	var hit_rr: float = 0.0
	var hit_side: float = 0.0
	for i in range(world.terrain.size()):
		var f: Dictionary = world.terrain[i]
		var rel: Vector2 = f["pos"] - pos
		var t: float = rel.dot(d)
		var rr: float = f["r"] + clear
		if t < -rr or t - rr > look:
			continue
		var miss: float = (rel - d * t).length()
		if miss >= rr:
			continue
		if t < hit_t:
			hit_t = t
			hit_i = i
			hit_rr = rr
			hit_side = -1.0 if (d.x * rel.y - d.y * rel.x) >= 0.0 else 1.0
	if hit_i < 0:
		if agent != null:
			agent.set_meta("av_f", -1)   # channel clear — release the committed side
		return INF
	var side: float = hit_side
	if agent != null:
		if int(agent.get_meta("av_f", -1)) == hit_i:
			side = float(agent.get_meta("av_s", hit_side))   # committed — keep rounding the same way
		else:
			agent.set_meta("av_f", hit_i)
			agent.set_meta("av_s", side)
	var feat: Dictionary = world.terrain[hit_i]
	var fpos: Vector2 = feat["pos"]
	var dc: float = pos.distance_to(fpos)
	var off: float
	if dc >= hit_rr:
		off = asin(minf(1.0, hit_rr / dc))                 # graze the tangent
	else:
		off = (PI / 2.0) * (2.0 - dc / hit_rr)             # inside the ring — spiral back out
	return atan2(fpos.x - pos.x, -(fpos.y - pos.y)) + side * off
