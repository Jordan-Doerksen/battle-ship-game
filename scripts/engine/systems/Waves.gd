class_name Waves
extends RefCounted
# C16 THE WAR, REPACKED (docs/specs/the-war-repacked.md) — system #2 in Sim.step's fixed order.
# Supersedes the C3 greedy blob director. The budget now buys FORMATION TEMPLATES (config data on
# WaveConfig) with SHAPE, assigned to ECHELONS that land in sequence — vanguard (0 s), main body
# (+main_delay ≈ 15 s), sting (+sting_delay ≈ 28 s) — building a crescendo; singles fill the
# remainder so the budget still spends EXACTLY. Formations bias toward open-water lanes; ambush_ok
# formations may instead stage behind a terrain feature on its far side. Between waves is a genuinely
# longer QUIET (quiet_secs). See _begin_wave / _compose_wave / _stage below — ported faithfully from
# the approved mockup (design/the-war-repacked.html, composeWave/stage/spawnEntry/stepWar).
#
# THE DETERMINISM CONTRACT (the load-bearing decision): COMPOSITION draws from a PER-WAVE SUBSTREAM
# keyed from (world_seed, wave) — NOT world.rng. So the same seed fields the same war no matter how
# the player fought earlier waves ("same seed = same war", matching C15's terrain). world.rng is left
# UNTOUCHED by the director: enemies carry no per-enemy behavior seed the director needs to set (the
# current Enemy has no ph/dir field and Enemies.gd seeds fire itself), so the director makes ZERO
# world.rng draws — determinism stays trivial. Two-world probes remain byte-identical.

const AMBUSH_NEAR: float = 600.0   # ambush country: a feature must sit between the ring and the ship —
const AMBUSH_FAR: float = 1100.0   #   near/far bounds from the ship (the mockup's d > 600 && d < 1100)
const AMBUSH_BACK: float = 90.0    # spawn this far past a feature's edge on its far side ("behind the rock")
const LANE_STEP: float = 150.0     # sample the ship→spawn approach every LANE_STEP against terrain
const LANE_PAD: float = 60.0       # clearance a formation body needs from a feature edge along a lane
const NUDGE_STEP: float = 40.0     # waterborne spawns nudge outward this far per step until clear
const SPLIT_MIN_SPACING: float = 60.0  # split halves get at least this unit spacing

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	var wc: WaveConfig = cfg.waves
	if world.hull < 0:                        # lazy one-time init from config (worlds start bare)
		world.hull = wc.hull_pips
	if world.lull_until < 0.0:
		world.lull_until = world.elapsed + wc.first_wave_delay
	if world.freeze_waves:                    # DEV test kit (debug builds): director paused
		return
	if world.wave_state == "lull":            # "lull" IS the REAL QUIET — nothing arrives, the plate breathes
		if world.elapsed >= world.lull_until:
			world.wave += 1
			_begin_wave(world, cfg)
			world.wave_state = "fighting"
	else:
		# drain the time-ordered spawn queue: each echelon LANDS when the wave clock reaches its rel
		while not world.wave_queue.is_empty() and (world.elapsed - world.wave_started) >= float(world.wave_queue[0]["rel"]):
			var entry: Dictionary = world.wave_queue.pop_front()
			_spawn_entry(world, cfg, entry)
		var any_active: bool = false
		for e in world.enemies:
			if e.active:
				any_active = true
				break
		# clears only when nothing's left to spawn AND nothing's alive AND the machine is down (C7)
		if not any_active and world.wave_queue.is_empty() and world.boss == null:
			world.enemies.clear()
			world.xp_run += cfg.progress.xp_wave_bonus * world.wave   # wave-clear bonus (C4) — KEPT
			world.effects.append({ "type": "waveclear", "wave": world.wave })
			world.wave_state = "lull"
			world.lull_until = world.elapsed + wc.quiet_secs          # the REAL QUIET (was C3 lull_secs)

# Compose the wave's PLAN + build its time-ordered spawn queue, and (on the ladder's Nth wave) field
# the war machine with a reduced-budget escort (C7, UNCHANGED). Boss creation draws from world.rng
# BEFORE composition, but composition rides the substream — the two never interfere.
static func _begin_wave(world: GameWorld, cfg: Configs) -> void:
	var wc: WaveConfig = cfg.waves
	var budget: int = wc.base_budget + wc.budget_per_wave * (world.wave - 1)
	var boss_wave: bool = cfg.bosses.every_n > 0 and world.wave % cfg.bosses.every_n == 0
	if boss_wave:
		var k: int = world.wave / cfg.bosses.every_n - 1
		var rung: int = k % cfg.bosses.defs.size()
		var lap: int = k / cfg.bosses.defs.size() + 1
		world.boss = Bosses.make_boss(world, cfg, rung, lap)
		world.effects.append({ "type": "klaxon", "name": cfg.bosses.defs[rung].display_name })
		budget = int(floor(budget * cfg.bosses.escort_frac))   # the machine has outriders
	var plan: Dictionary = _compose_wave(world, cfg, world.wave, budget)
	world.wave_started = world.elapsed
	world.wave_lines = plan["lines"]
	world.wave_ech_rel = plan["ech_rel"]
	var q: Array = plan["entries"].duplicate()
	q.sort_custom(_entry_before)              # total order (rel, then seq) — deterministic + stable
	world.wave_queue = q

# Queue ordering: earliest rel first; ties broken by composition sequence so the spawn order (and
# thus world.enemies iteration order) is a stable, deterministic function of the plan.
static func _entry_before(a: Dictionary, b: Dictionary) -> bool:
	if a["rel"] != b["rel"]:
		return a["rel"] < b["rel"]
	return a["seq"] < b["seq"]

# THE SPEND — one per-wave substream, stable draw order (the port contract): weighted template picks
# → greedy single fill → per-purchase staging (ring, ambush roll, bearing, ambush feature, offsets).
# Returns { entries, lines, ech_rel }. All draws below come from `wr`, never world.rng.
static func _compose_wave(world: GameWorld, cfg: Configs, wave: int, budget: int) -> Dictionary:
	var wr := Rng.new((int(world.world_seed) ^ (wave * 0x9E3779B9)) & 0xFFFFFFFF)
	var templates: Array = cfg.waves.templates()
	# templates first — weighted draw among affordable + unlocked, until the budget can't buy one
	var buys: Array = []
	while true:
		var aff: Array = []
		for td in templates:
			if int(td["min_wave"]) <= wave and _tpl_cost(td, cfg) <= budget and _tpl_unlocked(td, cfg, wave):
				aff.append(td)
		if aff.is_empty():
			break
		var tw: float = 0.0
		for ta in aff:
			tw += float(ta["weight"])
		var roll: float = wr.nextf() * tw
		var tpl: Dictionary = aff[aff.size() - 1]
		for tb in aff:
			roll -= float(tb["weight"])
			if roll <= 0.0:
				tpl = tb
				break
		budget -= _tpl_cost(tpl, cfg)
		buys.append(tpl)
	# singles fill the remainder exactly (the C3 greedy path, roster order = part of determinism)
	var singles: Array = []
	while true:
		var aff2: Array = []
		for dd in cfg.enemies.roster:
			if dd.unlock <= wave and dd.cost <= budget:
				aff2.append(dd)
		if aff2.is_empty():
			break
		var pick: EnemyDef = aff2[int(floor(wr.nextf() * float(aff2.size())))]
		budget -= pick.cost
		singles.append(pick)
	# echelon times — normalize so the earliest PURCHASED echelon lands at 0 (no dead air up front)
	var echT: Dictionary = { "vanguard": 0.0, "main": cfg.waves.main_delay, "sting": cfg.waves.sting_delay }
	var used: Dictionary = {}
	for tu in buys:
		used[tu["echelon"]] = true
	for su in singles:
		used[_single_ech(su.id)] = true
	var shift: float = INF
	for eu in used:
		shift = minf(shift, float(echT[eu]))
	if shift == INF:
		shift = 0.0
	# ambush country — features between the ring and the ship (COPIED center+r into the plan, so a
	# terrain regen can never dangle a live reference)
	var feats: Array = []
	for f in world.terrain:
		var fd: float = f["pos"].distance_to(world.ship_pos)
		if fd > AMBUSH_NEAR and fd < AMBUSH_FAR:
			feats.append(f)
	var plan: Dictionary = {
		"entries": [], "lines": { "vanguard": [], "main": [], "sting": [] },
		"ech_rel": {
			"vanguard": float(echT["vanguard"]) - shift,
			"main": float(echT["main"]) - shift,
			"sting": float(echT["sting"]) - shift,
		},
	}
	var ctx: Dictionary = { "echT": echT, "shift": shift, "feats": feats,
		"has_dominant": false, "dominant": 0.0, "seq": 0 }
	for bt in buys:
		_stage(world, cfg, wr, plan, ctx, bt, String(bt["name"]), String(bt["echelon"]), bt["members"])
	# singles: one group per distinct type, in first-seen order — "GNAT STRAGGLER ×N"
	var single_count: Dictionary = {}
	var single_order: Array = []
	for sc in singles:
		if not single_count.has(sc.id):
			single_order.append(sc)
		single_count[sc.id] = int(single_count.get(sc.id, 0)) + 1
	for so in single_order:
		var n2: int = int(single_count[so.id])
		var disp: String = "%s STRAGGLER%s" % [so.rep if so.rep != "" else so.id, (" ×%d" % n2) if n2 > 1 else ""]
		_stage(world, cfg, wr, plan, ctx, {}, disp, _single_ech(so.id), [{ "type": so.id, "n": n2, "delay": 0.0 }])
	# collapse duplicate line labels within each echelon: "GNAT SWARM ×2"
	for ech in ["vanguard", "main", "sting"]:
		var counts: Dictionary = {}
		var order: Array = []
		for l in plan["lines"][ech]:
			if not counts.has(l):
				order.append(l)
			counts[l] = int(counts.get(l, 0)) + 1
		var collapsed: Array[String] = []
		for l in order:
			collapsed.append(l if int(counts[l]) == 1 else "%s ×%d" % [l, int(counts[l])])
		plan["lines"][ech] = collapsed
	return plan

# Stage one formation (or one single group when tpl is the empty dict {}): resolve its echelon rel,
# anchor bearing(s), ambush, member offsets, and append its entries to the plan. `wr` draws happen in
# the mockup's exact order: ring → ambush roll → bearing → ambush feature → shape offsets. Mutates
# `plan` and `ctx` by reference.
static func _stage(world: GameWorld, cfg: Configs, wr: Rng, plan: Dictionary, ctx: Dictionary,
		tpl: Dictionary, disp_name: String, ech: String, members: Array) -> void:
	var has_tpl: bool = not tpl.is_empty()
	var echT: Dictionary = ctx["echT"]
	var rel: float = float(echT[ech]) - float(ctx["shift"])
	var surface: bool = false
	for sm in members:
		if cfg.enemies.by_id(String(sm["type"])).layer != "air":
			surface = true
			break
	var ring: float = cfg.waves.spawn_ring_min + wr.nextf() * (cfg.waves.spawn_ring_max - cfg.waves.spawn_ring_min)
	var split: float = 0.0
	if has_tpl and String(tpl["shape"]).begins_with("split:"):
		split = float(String(tpl["shape"]).substr(6)) * PI / 180.0
	var ambush: bool = false
	if has_tpl and bool(tpl.get("ambush_ok", false)) and not ctx["feats"].is_empty():
		ambush = wr.nextf() < cfg.waves.ambush_chance
	var bearing: float
	if has_tpl and bool(tpl.get("flank", false)) and bool(ctx["has_dominant"]):
		var sgn: float = -1.0 if wr.nextf() < 0.5 else 1.0
		bearing = float(ctx["dominant"]) + sgn * (70.0 + wr.nextf() * 40.0) * PI / 180.0
	elif surface:
		bearing = _pick_lane(world, wr, ring)   # waterborne: prefer an open channel
	else:
		bearing = wr.nextf() * TAU               # air ignores lanes
	if not bool(ctx["has_dominant"]):
		ctx["dominant"] = bearing
		ctx["has_dominant"] = true
	var anchors: Array = [bearing] if split == 0.0 else [bearing - split / 2.0, bearing + split / 2.0]
	# ambush: each anchor swaps its ring spawn for a feature's far side; features are COPIED (center+r)
	var amb_feats = null
	if ambush:
		amb_feats = []
		for ai in range(anchors.size()):
			var ff: Dictionary = ctx["feats"][int(floor(wr.nextf() * float(ctx["feats"].size())))]
			amb_feats.append({ "pos": ff["pos"], "r": float(ff["r"]) })
	# flatten members into per-unit entries carrying their group delay
	var flat: Array = []
	for fm in members:
		var md: float = float(fm.get("delay", 0.0))
		for i in range(int(fm["n"])):
			flat.append({ "type": String(fm["type"]), "delay": md })
	var shape: String = "line"
	if has_tpl:
		shape = "line" if split != 0.0 else String(tpl["shape"])
	var spacing: float = float(tpl["spacing"]) if has_tpl else 0.0
	var off_spacing: float = maxf(spacing, SPLIT_MIN_SPACING) if split != 0.0 else spacing
	var per_anchor: Array = []
	for pa in range(anchors.size()):
		per_anchor.append([])
	for fi in range(flat.size()):
		per_anchor[fi % anchors.size()].append(flat[fi])
	for gi in range(anchors.size()):
		var b: float = float(anchors[gi])
		var group: Array = per_anchor[gi]
		var offs: Array = _shape_offsets(shape, group.size(), off_spacing, wr)
		for ui in range(group.size()):
			var f: Dictionary = group[ui]
			var feat_val = amb_feats[gi] if amb_feats != null else null
			plan["entries"].append({
				"rel": rel + float(f["delay"]), "type": f["type"], "bearing": b, "ring": ring,
				"ox": offs[ui].x, "oy": offs[ui].y, "feat": feat_val, "seq": int(ctx["seq"]),
			})
			ctx["seq"] = int(ctx["seq"]) + 1
	plan["lines"][ech].append(disp_name + (" — AMBUSH" if ambush else ""))

# LANES — score a candidate bearing by open water along the ship→ring approach (sampled every
# LANE_STEP against the feature circles). 1.0 = a fully clear channel.
static func _lane_score(world: GameWorld, bearing: float, ring: float) -> float:
	var d := Vector2(sin(bearing), -cos(bearing))
	var clear: int = 0
	var n: int = 0
	var s: float = LANE_STEP
	while s <= ring:
		n += 1
		if Terrain.clear_of(world, world.ship_pos + d * s, LANE_PAD):
			clear += 1
		s += LANE_STEP
	return float(clear) / float(n) if n > 0 else 1.0

# Pick a waterborne anchor bearing: among 16 candidates off a seeded base, choose randomly among the
# FULLY clear lanes if any exist (heavily prefer open channels), else the best-scored bearing.
static func _pick_lane(world: GameWorld, wr: Rng, ring: float) -> float:
	var base: float = wr.nextf() * TAU
	var cands: Array = []
	for k in range(16):
		var b: float = base + (float(k) / 16.0) * TAU
		cands.append({ "b": b, "s": _lane_score(world, b, ring) })
	var open: Array = []
	for c in cands:
		if float(c["s"]) >= 0.999:
			open.append(c)
	if not open.is_empty():
		return float(open[int(floor(wr.nextf() * float(open.size())))]["b"])
	var best: Dictionary = cands[0]
	for c2 in cands:
		if float(c2["s"]) > float(best["s"]):
			best = c2
	return float(best["b"])

# SHAPE OFFSETS — the formation frame: +ox = right of the bearing, +oy = further OUT (behind the
# anchor, away from the ship). wedge = a V pointing at the ship · line = abreast · loose =
# echelon-right with seeded jitter. Each split half is drawn as a line. Only "loose" draws from wr.
static func _shape_offsets(shape: String, n: int, spacing: float, wr: Rng) -> Array:
	var out: Array = []
	for i in range(n):
		if shape == "wedge":
			var kk: int = int(ceil(float(i) / 2.0))
			var side: int = 0
			if i != 0:
				side = -1 if (i % 2 == 1) else 1
			out.append(Vector2(float(side * kk) * spacing, float(kk) * spacing * 0.8))
		elif shape == "loose":
			var ox: float = float(i) * spacing + (wr.nextf() - 0.5) * spacing * 0.5
			var oy: float = float(i) * spacing * 0.6 + (wr.nextf() - 0.5) * spacing * 0.5
			out.append(Vector2(ox, oy))
		else:   # line (and each split half)
			out.append(Vector2((float(i) - float(n - 1) / 2.0) * spacing, 0.0))
	return out

# Resolve a spawn position at SPAWN TIME (not compose time): ring spawns are ship-relative (the body
# arrives beyond the ring wherever she now is); ambush spawns are TERRAIN-relative (the rock didn't
# move — they were waiting behind it). Waterborne spawns nudge radially outward past terrain (the
# C15 rule). Sets only the Enemy fields the current entity carries — no invented behavior seed, so
# no world.rng draw (the director's determinism stays trivial).
static func _spawn_entry(world: GameWorld, cfg: Configs, en: Dictionary) -> void:
	var def: EnemyDef = cfg.enemies.by_id(String(en["type"]))
	var u: Vector2
	var pos: Vector2
	if en["feat"] != null:
		var feat: Dictionary = en["feat"]
		u = _dir_of(_angle_to(world.ship_pos, feat["pos"]))   # ship → rock: "behind" is the far side
		var rgt := Vector2(-u.y, u.x)
		pos = feat["pos"] + u * (float(feat["r"]) + AMBUSH_BACK + float(en["oy"])) + rgt * float(en["ox"])
	else:
		u = _dir_of(float(en["bearing"]))
		var rgt := Vector2(-u.y, u.x)
		pos = world.ship_pos + u * (float(en["ring"]) + float(en["oy"])) + rgt * float(en["ox"])
	if def.layer != "air":
		var nudges: int = 0
		while nudges < 60 and not Terrain.clear_of(world, pos, NUDGE_STEP):
			nudges += 1
			pos += u * NUDGE_STEP
	var e := Enemy.new()
	e.type_id = def.id
	e.layer = def.layer
	e.hp = def.hp
	e.hp_max = def.hp
	e.active = true
	e.pos = pos
	e.heading = _angle_to(pos, world.ship_pos)
	world.enemies.append(e)

# Template cost = Σ member costs; member unlocks are respected (min_wave already encodes them, this
# is the defensive backstop the spec calls for).
static func _tpl_cost(t: Dictionary, cfg: Configs) -> int:
	var c: int = 0
	for m in t["members"]:
		c += cfg.enemies.by_id(String(m["type"])).cost * int(m["n"])
	return c

static func _tpl_unlocked(t: Dictionary, cfg: Configs, wave: int) -> bool:
	for m in t["members"]:
		if cfg.enemies.by_id(String(m["type"])).unlock > wave:
			return false
	return true

# Which echelon a single (no-formation straggler) lands in — mirrors the mockup's SINGLE_ECH.
static func _single_ech(type_id: String) -> String:
	match type_id:
		"swarmer": return "vanguard"
		"gunboat": return "main"
		"sub": return "main"
		"wasp": return "sting"
		"bomber": return "sting"
	return "vanguard"

static func _dir_of(a: float) -> Vector2:
	return Vector2(sin(a), -cos(a))

static func _angle_to(from: Vector2, to: Vector2) -> float:
	return atan2(to.x - from.x, -(to.y - from.y))
