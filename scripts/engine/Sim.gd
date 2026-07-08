class_name Sim
extends RefCounted
# The deterministic step root (DECISIONS D1.4). ONE fixed-timestep tick mutates `world` in a stable,
# index-ordered sequence. Called only by Main's fixed-step accumulator (or a headless probe) — never
# from a render path. Each system is a static func taking its own <Domain>Config; the call order below
# is part of determinism.

static func step(world: GameWorld, dt: float, cfg: Configs) -> void:
	world.elapsed += dt
	world.tick += 1
	Movement.step(world, dt, cfg.movement)     # C1 — naval momentum/turning, always system #1
	Drones.step(world, dt, cfg)                # C2 — practice-range targets
	Turrets.step(world, dt, cfg)               # C2 — hardpoint targeting/traverse/fire
	Projectiles.step(world, dt, cfg)           # C2 — shells, hits, splash, kill/respawn
	# …future: Sonar/DepthCharges/Spawn — later chunks, each reading its own <Domain>Config.tres
	if world.effects.size() > 400:             # render drains every frame; cap is a headless backstop
		world.effects = world.effects.slice(world.effects.size() - 400)
