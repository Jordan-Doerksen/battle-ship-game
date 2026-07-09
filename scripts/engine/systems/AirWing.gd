class_name AirWing
extends RefCounted
# C6 AIR WING (docs/specs/air-wing.md) — the autonomous ASW wingman, after DepthCharges in
# Sim.step's fixed order. Inert (zero state writes, zero draws) without tech.helo — zero-tech runs
# are byte-identical to C5 (probe-gated). One bird, one state machine on GameWorld: pad → air
# (escort weave / prosecute) → rtb → pad. Its dipping sonar writes the SAME contact latch as
# Sonar.gd (two listeners, one truth; MAD GEAR makes ITS latches permanent). The light rack drops
# contact-centered patterns that soften — the ship's stern racks remain the killer (detector-
# first). Door gunners (gate rev 2) pepper nearby air/surface targets; the deep draws no gun fire.
# The ONLY world.rng draws are drop scatter and door-gun rounds (spread, then reach; gunner order).

const PAD_LOCAL := Vector2(0, 65)      # the C1 hull's stern helipad, hull-local
const LAND_RANGE: float = 20.0         # close enough to flare and set down
# throttle shape (gate rev 1): ease to station-keeping near the aim point, open up when far —
# flight-model constants, not balance tunables (the tunables are speed/turn/speed_margin)
const THROTTLE_BASE: float = 50.0
const THROTTLE_SHIP: float = 0.9
const THROTTLE_DIST: float = 1.6

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	if not cfg.tech.helo:
		return
	var aw: AirWingConfig = cfg.airwing
	world.helo_drop_cool -= dt
	world.helo_gun_cool -= dt
	if world.helo_state == "pad":
		world.helo_pos = _pad(world)
		world.helo_heading = world.ship_heading   # lashed to the pad
		world.helo_rearm -= dt
		if world.helo_rearm <= 0.0:
			world.helo_state = "air"
			world.helo_fuel = aw.patrol_secs
		return
	# airborne (air | rtb): burn fuel, steer, detect, drop, gun
	if world.helo_state == "air":
		world.helo_fuel -= dt
		if world.helo_fuel <= 0.0:
			world.helo_state = "rtb"
	# aim point: home pad → live contact → torpedo launch point → the escort weave
	var pt: Vector2
	if world.helo_state == "rtb":
		pt = _pad(world)
		if world.helo_pos.distance_to(pt) <= LAND_RANGE:
			world.helo_state = "pad"
			world.helo_rearm = aw.turnaround_secs
			world.effects.append({ "type": "helodown", "pos": pt })
	else:
		var tgt: Enemy = _nearest_contact(world)
		if tgt != null:
			pt = tgt.pos
		elif world.elapsed < world.helo_mark_until:
			pt = world.helo_mark
		else:
			# gate rev 1: a smooth S-weave across the bow that rides the ship and leads further
			# ahead as the ship speeds up; the throttle below keeps it from overshooting.
			world.helo_phase += aw.weave_rate * dt
			var f := Vector2(sin(world.ship_heading), -cos(world.ship_heading))
			var r := Vector2(-f.y, f.x)
			var ship_spd0: float = world.ship_vel.length()
			var along: float = (world.helo_pos - world.ship_pos).dot(f)
			if along < 0.0:   # caught astern: beeline to the bow station, no lateral wandering
				pt = world.ship_pos + f * aw.picket_dist
			else:
				var ahead: float = (aw.picket_dist + ship_spd0) * (0.72 + 0.28 * sin(world.helo_phase * 0.53))
				var across: float = aw.weave_amp * sin(world.helo_phase)
				pt = world.ship_pos + f * ahead + r * across
	var desired: float = atan2(pt.x - world.helo_pos.x, -(pt.y - world.helo_pos.y))
	world.helo_heading += clampf(angle_difference(world.helo_heading, desired), -aw.turn * dt, aw.turn * dt)
	# gate rev 1: a helicopter has a THROTTLE — near its point it eases to station-keeping (which
	# scales with the ship's own speed, so flank never leaves it astern); far out it opens to a
	# top speed that also rises with the ship's. No shell-style overshoot + U-turn plunges.
	var ship_spd: float = world.ship_vel.length()
	var dist_pt: float = world.helo_pos.distance_to(pt)
	var top: float = maxf(aw.speed, ship_spd + aw.speed_margin)
	var spd: float = minf(top, THROTTLE_BASE + ship_spd * THROTTLE_SHIP + dist_pt * THROTTLE_DIST)
	world.helo_pos += Vector2(sin(world.helo_heading), -cos(world.helo_heading)) * spd * dt
	# dipping sonar: same latch as the ship's ears. MAD GEAR (marquee): the BIRD'S contacts never
	# decay — ship-made latches still do.
	for e in world.enemies:
		if not e.active or e.layer != "sub":
			continue
		if e.pos.distance_to(world.helo_pos) <= aw.dip_radius:
			if world.elapsed >= e.detected_until:
				world.effects.append({ "type": "contact", "pos": e.pos })
			e.detected_until = 1e12 if cfg.tech.mad_gear else world.elapsed + cfg.sonar.contact_hold
	# the light rack: nearly overhead a DETECTED sub, a tight pattern falls on the CONTACT
	if world.helo_state == "air" and world.helo_drop_cool <= 0.0:
		for e in world.enemies:
			if not e.active or e.layer != "sub" or not Sonar.detected(world, e):
				continue
			if e.pos.distance_to(world.helo_pos) > aw.drop_range:
				continue
			world.helo_drop_cool = aw.dc_cooldown
			for i in range(aw.dc_count):
				var ox: float = (world.rng.nextf() * 2.0 - 1.0) * aw.dc_scatter
				var oy: float = (world.rng.nextf() * 2.0 - 1.0) * aw.dc_scatter
				var p: Projectile = world.projectiles.obtain()
				p.pos = e.pos + Vector2(ox, oy)
				p.vel = Vector2.ZERO
				p.dmg = aw.dc_dmg
				p.splash = 0.0
				p.hostile = false
				p.wid = "dc"
				p.life = cfg.sonar.dc_fuse
			world.effects.append({ "type": "helodrop", "pos": world.helo_pos })
			break
	# gate rev 2: DOOR GUNNERS — weak, wild, glorious. Nearest air/surface target near the bird;
	# every round rolls spread AND a short reach, so bursts stitch the water before max range.
	if aw.gunners > 0 and world.helo_state == "air" and world.helo_gun_cool <= 0.0:
		var gt: Enemy = null
		var gbest: float = INF
		for e in world.enemies:
			if not e.active or e.layer == "sub":   # the deep stays deaf to gunfire
				continue
			var d2: float = e.pos.distance_to(world.helo_pos)
			if d2 <= aw.gun_range and d2 < gbest:
				gbest = d2
				gt = e
		if gt != null:
			world.helo_gun_cool = 1.0 / aw.gun_rate
			for g in range(aw.gunners):
				var ang: float = atan2(gt.pos.x - world.helo_pos.x, -(gt.pos.y - world.helo_pos.y)) \
					+ (world.rng.nextf() * 2.0 - 1.0) * aw.gun_spread   # no lead — that's the charm
				var reach: float = (0.4 + 0.6 * world.rng.nextf()) * aw.gun_range
				var gd := Vector2(sin(ang), -cos(ang))
				var p: Projectile = world.projectiles.obtain()
				p.pos = world.helo_pos + gd * 10.0
				p.vel = gd * aw.gun_speed
				p.dmg = aw.gun_dmg
				p.splash = 0.0
				p.hostile = false
				p.wid = "doorgun"
				p.life = reach / aw.gun_speed

static func _pad(world: GameWorld) -> Vector2:
	return world.ship_pos + PAD_LOCAL.rotated(world.ship_heading)

static func _nearest_contact(world: GameWorld) -> Enemy:
	var best: Enemy = null
	var best_d: float = INF
	for e in world.enemies:
		if not e.active or e.layer != "sub" or not Sonar.detected(world, e):
			continue
		var d: float = e.pos.distance_to(world.helo_pos)
		if d < best_d:
			best_d = d
			best = e
	return best
