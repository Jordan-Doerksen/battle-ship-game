class_name Projectiles
extends RefCounted
# Shells in flight (C2 spec + C3 revisions) — last system in Sim.step's fixed order.
# Friendly direct shells hit whatever enemy they physically reach (domain tags gate TARGETING only,
# D1.9). Friendly splash shells carry a PROXIMITY FUSE (C3 gate rev 2): they detonate on a close
# flyby of a surface enemy, else burst when their flight time expires (auto: at the intercept;
# forced: at full range along the bearing). Hostile shells test the hull capsule and go through
# Hull.damage (grace window applies). Kill bookkeeping banks world.kills and emits effects.

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	var pool: Pool = world.projectiles
	for i in range(pool.items.size()):
		var p: Projectile = pool.items[i]
		if not p.active:
			continue
		p.pos += p.vel * dt
		p.life -= dt
		var dead: bool = p.life <= 0.0
		if p.hostile:
			if Hull.dist_to_hull(world, p.pos) <= Hull.RADIUS:
				Hull.damage(world, p.dmg, cfg)
				world.effects.append({ "type": "shiphit", "pos": p.pos })
				dead = true
		elif p.splash > 0.0:
			if not dead:   # proximity fuse: detonate on a close flyby of a surface enemy
				for e in world.enemies:
					if e.active and e.layer == "surf" \
						and e.pos.distance_to(p.pos) <= cfg.enemies.by_id(e.type_id).radius + 4.0:
						dead = true
						break
			if dead:
				world.effects.append({ "type": "splash", "pos": p.pos, "r": p.splash })
				for e in world.enemies:
					if e.active and e.layer == "surf" and e.pos.distance_to(p.pos) <= p.splash:
						damage_enemy(world, e, p.dmg, cfg)
		elif p.wid == "dc":
			# depth charge (C5): inert while sinking; at fuse depth it blasts SUBS only — the ship
			# and surface/air enemies are untouched by the underwater detonation
			if dead:
				world.effects.append({ "type": "dcblast", "pos": p.pos, "r": cfg.sonar.dc_blast })
				for e in world.enemies:
					if e.active and e.layer == "sub" and e.pos.distance_to(p.pos) <= cfg.sonar.dc_blast:
						damage_enemy(world, e, p.dmg, cfg)
		elif p.wid == "dp5" and cfg.tech.airburst:
			# PROXIMITY BURST (C4 marquee): 5-in shells become flak vs air — near-miss detonation, AoE
			var burst: bool = false
			for e in world.enemies:
				if not e.active or e.layer == "sub":   # the deep neither triggers nor feels flak (C5 law)
					continue
				var trigger: float = cfg.enemies.by_id(e.type_id).radius \
					+ (cfg.tech.airburst_trigger if e.layer == "air" else 2.0)
				if e.pos.distance_to(p.pos) <= trigger:
					burst = true
					break
			if burst:
				world.effects.append({ "type": "airburst", "pos": p.pos, "r": cfg.tech.airburst_radius })
				for e in world.enemies:
					if e.active and e.layer != "sub" and e.pos.distance_to(p.pos) <= cfg.tech.airburst_radius + cfg.enemies.by_id(e.type_id).radius:
						damage_enemy(world, e, p.dmg, cfg)
				dead = true
		else:
			var struck: bool = false
			for e in world.enemies:
				if not e.active or e.layer == "sub":   # shells fly OVER the deep (C5 law) — domain
					continue                            # tags gate targeting; PHYSICS spares subs too
				if e.pos.distance_to(p.pos) <= cfg.enemies.by_id(e.type_id).radius + 2.0:
					damage_enemy(world, e, p.dmg, cfg)
					_ignite_if_incendiary(world, cfg, e, p.wid)
					struck = true
					dead = true
					break
			if not struck and p.life <= 0.0 and p.wid == "doorgun":
				world.effects.append({ "type": "gunsplash", "pos": p.pos })   # the round slaps the sea (C6)
		if dead:
			pool.release(p)

# shared with Enemies.gd's burn ticks — kills bank kills + XP (C4)
static func damage_enemy(world: GameWorld, e: Enemy, dmg: int, cfg: Configs) -> void:
	e.hp -= dmg
	if e.hp <= 0:
		e.active = false
		world.kills += 1
		world.xp_run += cfg.progress.xp_for_kill(e.type_id)
		world.effects.append({ "type": "death", "pos": e.pos, "layer": e.layer })
	else:
		world.effects.append({ "type": "hit", "pos": e.pos })

# INCENDIARY LOAD (C4 marquee): aa20 hits set air enemies burning
static func _ignite_if_incendiary(world: GameWorld, cfg: Configs, e: Enemy, wid: String) -> void:
	if cfg.tech.incendiary and wid == "aa20" and e.active and e.layer == "air" and e.burn_left <= 0:
		e.burn_left = cfg.tech.burn_ticks
		e.next_burn = world.elapsed + 1.0
		world.effects.append({ "type": "ignite", "pos": e.pos })
