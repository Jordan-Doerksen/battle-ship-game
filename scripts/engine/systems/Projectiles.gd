class_name Projectiles
extends RefCounted
# Shells in flight (C2 spec + C3 revisions) — last system in Sim.step's fixed order.
# Friendly direct shells hit whatever enemy they physically reach (domain tags gate TARGETING only,
# D1.9). Friendly splash shells carry a PROXIMITY FUSE (C3 gate rev 2): they detonate on a close
# flyby of a surface enemy, else burst when their flight time expires (auto: at the intercept;
# forced: at full range along the bearing). Hostile shells test the hull capsule and go through
# Hull.damage (grace window applies); hostile SPLASH shells (the CANOPY's bay bombs, C7) also
# burst at flight end and splash the hull in radius. Kill bookkeeping banks world.kills and
# emits effects.

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	var pool: Pool = world.projectiles
	for i in range(pool.items.size()):
		var p: Projectile = pool.items[i]
		if not p.active:
			continue
		var prev: Vector2 = p.pos
		# C18 THE WHIRLPOOL — torpedoes run shallow: the vortex bends them off their line (mass
		# tier ×1.6) — a shield you keep between yourself and the wolfpack. Shells fly over.
		if p.wid == "torpedo":
			var vbend: Vector2 = Whirlpool.field(world, cfg, p.pos)
			if vbend != Vector2.ZERO:
				p.vel += vbend * cfg.whirlpool.mult_torp * dt
		p.pos += p.vel * dt
		p.life -= dt
		# C15 land rules (DECISIONS Change Log 2026-07-10, verbatim owner rule): terrain blocks
		# everything that isn't flying. Torpedoes ALWAYS die on rock — whoever dropped them, even
		# an air-dropped fish runs IN the water. Aerial ordnance (air-layer shots, bay bombs), the
		# door gun (its AirWing spawner is outside this chunk — the wid stands in for the flag),
		# and the AA guns pass. Depth charges dud at the THROW (DepthCharges.gd), never in flight.
		# mb16 IS blocked — islands are hard cover against naval gunfire both ways (supersedes the
		# earlier arc-over detail). Segment-swept so a fast shell can't tunnel a thin rock.
		if not world.terrain.is_empty():
			var flies: bool = (p.aerial or p.wid == "doorgun" or p.wid == "aa20") \
				and p.wid != "torpedo"
			if not flies and p.wid != "dc":
				var rock: Vector2 = Terrain.hit(world, prev, p.pos)
				if rock.x != INF:
					world.effects.append({ "type": "rockhit", "pos": rock })
					p.pos = rock
					p.aerial = false   # pool-reset (see the release below)
					pool.release(p)
					continue
		var dead: bool = p.life <= 0.0
		if p.hostile:
			if Hull.dist_to_hull(world, p.pos) <= Hull.RADIUS:
				Hull.damage(world, p.dmg, cfg)
				world.effects.append({ "type": "shiphit", "pos": p.pos })
				dead = true
			elif dead and p.splash > 0.0:
				# CANOPY bay bombs are SPLASH attacks (C7 spec table, boss-ladder.md) — the bomb
				# bursts where its flight expires (it was lobbed AT a point) and the hull takes
				# the hit if the blast reaches the capsule: same capsule idiom as the contact
				# test above, widened by the blast radius. Grace still applies via Hull.damage.
				world.effects.append({ "type": "splash", "pos": p.pos, "r": p.splash, "hostile": true })
				if Hull.dist_to_hull(world, p.pos) <= Hull.RADIUS + p.splash:
					Hull.damage(world, p.dmg, cfg)
			elif dead and p.wid != "torpedo":
				# C9 (cosmetic-only append, no rng): a hostile shell that misses still hits the SEA —
				# near-miss columns around the hull are the straddle read. Spent torpedoes sink silent.
				world.effects.append({ "type": "splash", "pos": p.pos, "r": 12.0, "hostile": true })
		elif p.splash > 0.0:
			if not dead:   # proximity fuse: detonate on a close flyby of a surface enemy
				for e in world.enemies:
					if e.active and e.layer == "surf" \
						and e.pos.distance_to(p.pos) <= cfg.enemies.by_id(e.type_id).radius + 4.0:
						dead = true
						break
				if not dead and world.boss != null and Bosses.domain_of(world, cfg) == "surface" \
						and world.boss.pos.distance_to(p.pos) <= Bosses.def_of(world, cfg).radius + 4.0:
					dead = true   # C7: the fuse triggers off a surfaced machine too
			if dead:
				world.effects.append({ "type": "splash", "pos": p.pos, "r": p.splash })
				for e in world.enemies:
					if e.active and e.layer == "surf" and e.pos.distance_to(p.pos) <= p.splash:
						damage_enemy(world, e, p.dmg, cfg)
				if world.boss != null and Bosses.domain_of(world, cfg) == "surface" \
						and world.boss.pos.distance_to(p.pos) <= p.splash + Bosses.def_of(world, cfg).radius:
					Bosses.strike(world, cfg, _boss_burst_point(world, cfg, p.pos), p.dmg, ["surface"])
		elif p.wid == "dc":
			# depth charge (C5): inert while sinking; at fuse depth it blasts SUBS only — the ship
			# and surface/air enemies are untouched by the underwater detonation
			if dead:
				world.effects.append({ "type": "dcblast", "pos": p.pos, "r": cfg.sonar.dc_blast })
				for e in world.enemies:
					if e.active and e.layer == "sub" and e.pos.distance_to(p.pos) <= cfg.sonar.dc_blast:
						damage_enemy(world, e, p.dmg, cfg)
				if world.boss != null and Bosses.domain_of(world, cfg) == "sub" \
						and world.boss.pos.distance_to(p.pos) <= cfg.sonar.dc_blast + Bosses.def_of(world, cfg).radius:
					Bosses.damage(world, cfg, -1, p.dmg)   # the deep answers to the racks alone (C7)
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
			if not burst and world.boss != null and Bosses.domain_of(world, cfg) != "sub":
				# the machine is a fuse target too (C7 fix — dp5 is air+surface, and with the
				# tech on this elif consumes every dp5 shell, so the generic strike below can
				# never reach a boss). The submerged MAW neither triggers nor feels flak.
				var btrigger: float = Bosses.def_of(world, cfg).radius \
					+ (cfg.tech.airburst_trigger if Bosses.domain_of(world, cfg) == "air" else 2.0)
				if world.boss.pos.distance_to(p.pos) <= btrigger:
					burst = true
			if burst:
				world.effects.append({ "type": "airburst", "pos": p.pos, "r": cfg.tech.airburst_radius })
				for e in world.enemies:
					if e.active and e.layer != "sub" and e.pos.distance_to(p.pos) <= cfg.tech.airburst_radius + cfg.enemies.by_id(e.type_id).radius:
						damage_enemy(world, e, p.dmg, cfg)
				if world.boss != null \
						and world.boss.pos.distance_to(p.pos) <= cfg.tech.airburst_radius + Bosses.def_of(world, cfg).radius:
					Bosses.strike(world, cfg, _boss_burst_point(world, cfg, p.pos), p.dmg, ["air", "surface"])
				dead = true
			elif dead:
				# C9 (cosmetic-only): an unburst flak shell falls into the sea at flight's end
				world.effects.append({ "type": "splash", "pos": p.pos, "r": 16.0 })
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
			if not struck and Bosses.strike(world, cfg, p.pos, p.dmg, Bosses.WPN_DOMAINS.get(p.wid, ["air", "surface"])):
				struck = true
				dead = true
			if not struck and p.life <= 0.0:
				# C9 (cosmetic-only appends, no rng): spent rounds hit the SEA — misses read as water
				if p.wid == "doorgun" or p.wid == "aa20":
					world.effects.append({ "type": "gunsplash", "pos": p.pos })   # the round slaps the sea (C6/C9)
				elif p.wid == "dp5":
					world.effects.append({ "type": "splash", "pos": p.pos, "r": 16.0 })   # near-miss column
		if dead:
			# C15 pool-reset: every release routes through Projectiles.step, so clearing the flag
			# HERE guarantees recycled slots never leak `aerial` into spawners that don't write it
			# (Turrets' mb16/dp5/aa20 and AirWing's rounds are outside this chunk's files)
			p.aerial = false
			pool.release(p)

# AoE strikes on the machine resolve at the BURST point, so part-first attribution and hit
# effects happen where the blast actually is (C7 fix — passing the boss CENTER made off-center
# parts unhittable by splash/flak and drew effects at the wrong spot). The point is clamped to
# the hull disc: the callers' range gates already proved the blast reaches the hull, so an edge
# burst must still land — unclamped it would miss strike()'s point-contact checks (part r + 2 /
# core radius + 2) and deal nothing, losing damage the old center-pass code dealt.
static func _boss_burst_point(world: GameWorld, cfg: Configs, burst: Vector2) -> Vector2:
	return world.boss.pos + (burst - world.boss.pos).limit_length(Bosses.def_of(world, cfg).radius)

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
