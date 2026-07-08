class_name Turrets
extends RefCounted
# Hardpoint turrets (C2 spec, re-targeted at C3 enemies; docs/specs/{hardpoint-hull,wave-director}.md).
# Per mount, in mount-index order: pick a target (weapon policy, or the forced cursor point), slew
# the barrel clamped by the weapon's traverse rate, fire when aligned within tolerance.
# Force-fire is hold-only: LMB = ALL mounts with domain tags OVERRIDDEN; RMB = large only;
# MMB = medium only (C3 gate rev 1); RMB+MMB combine. Forced splash shells fly their FULL range
# along the cursor bearing (C3 gate rev 2 — the cursor sets bearing, not burst point; the radar lays
# the main battery on contacts beyond the screen). Only per-shot spread draws from world.rng.

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	var hp_cfg: HardpointConfig = cfg.hardpoints
	while world.mounts.size() < hp_cfg.mount_pos.size():
		world.mounts.append(Mount.new())
	if world.mounts.size() > hp_cfg.mount_pos.size():
		world.mounts.resize(hp_cfg.mount_pos.size())
	for i in range(world.mounts.size()):
		var m: Mount = world.mounts[i]
		var size: String = hp_cfg.mount_size[i]
		var wpn: WeaponDef = cfg.weapons.by_id(hp_cfg.loadout[size])
		if wpn == null:
			continue
		var mpos: Vector2 = mount_world(world, hp_cfg.mount_pos[i])
		var forced: bool = world.input.force_all \
			or (world.input.force_large and size == "L") \
			or (world.input.force_medium and size == "M")
		var aim: Vector2 = Vector2.INF
		if forced:
			aim = world.input.aim_world
			m.mode = "forced"
		else:
			var tgt: Enemy = _pick_target(world, wpn, mpos)
			if tgt != null:
				# lead the target: aim at the intercept, not the current position — without this,
				# anything moving crosswise (an orbiting gunboat) outruns every shell forever
				var tdef: EnemyDef = cfg.enemies.by_id(tgt.type_id)
				var flight: float = tgt.pos.distance_to(mpos) / wpn.speed
				var tvel: Vector2 = Vector2(sin(tgt.heading), -cos(tgt.heading)) * (tdef.speed if tdef != null else 0.0)
				aim = tgt.pos + tvel * flight
				m.mode = "auto"
			else:
				m.mode = "stow"
		var has_aim: bool = aim != Vector2.INF
		var desired: float = _angle_to(mpos, aim) if has_aim else world.ship_heading   # stow: home to bow
		m.ang += clampf(angle_difference(m.ang, desired), -wpn.traverse * dt, wpn.traverse * dt)
		m.cool -= dt
		m.bloom = maxf(0.0, m.bloom - wpn.bloom_decay * dt)   # cone tightens while the gun rests
		if has_aim and m.cool <= 0.0 and absf(angle_difference(m.ang, desired)) <= hp_cfg.aim_tol:
			m.cool = 1.0 / wpn.rate
			var shot_ang: float = m.ang + (world.rng.nextf() * 2.0 - 1.0) * (wpn.spread + m.bloom)
			m.bloom = minf(wpn.bloom_max, m.bloom + wpn.bloom_add)
			var p: Projectile = world.projectiles.obtain()
			p.pos = mpos
			p.vel = Vector2(sin(shot_ang), -cos(shot_ang)) * wpn.speed
			p.dmg = wpn.dmg
			p.splash = wpn.splash
			p.hostile = false
			p.wid = wpn.id
			p.life = wpn.range_u / wpn.speed
			# AUTO splash shells burst at their computed intercept; FORCED ones fly full range (rev 2)
			if wpn.splash > 0.0 and not forced:
				p.life = minf(mpos.distance_to(aim), wpn.range_u) / wpn.speed
			world.effects.append({ "type": "muzzle", "idx": i, "pos": mpos, "ang": m.ang, "size": size })

static func mount_world(world: GameWorld, local: Vector2) -> Vector2:
	return world.ship_pos + local.rotated(world.ship_heading)

static func _angle_to(from: Vector2, to: Vector2) -> float:
	return atan2(to.x - from.x, -(to.y - from.y))   # heading space: 0 = north, positive clockwise

static func _pick_target(world: GameWorld, wpn: WeaponDef, mpos: Vector2) -> Enemy:
	var best: Enemy = null
	var best_key: float = INF
	for e in world.enemies:
		if not e.active:
			continue
		var domain: String = "air" if e.layer == "air" else "surface"
		if not wpn.domains.has(domain):
			continue
		var dist: float = e.pos.distance_to(mpos)
		if dist > wpn.range_u:
			continue
		# STRONG: toughest first, ties by distance; CLOSE: nearest
		var key: float = (-e.hp_max * 1e6 + dist) if wpn.policy == "STRONG" else dist
		if key < best_key:
			best_key = key
			best = e
	return best
