class_name Sim
extends RefCounted
# The deterministic step root (DECISIONS D1.4). ONE fixed-timestep tick mutates `world` in a stable,
# index-ordered sequence. Called only by Main's fixed-step accumulator (or a headless probe) — never
# from a render path. Each system is a static func taking its own <Domain>Config; the call order below
# is part of determinism.

static func step(world: GameWorld, dt: float, movement_cfg: MovementConfig) -> void:
	world.elapsed += dt
	world.tick += 1
	Movement.step(world, dt, movement_cfg)   # C1 — naval momentum/turning, always system #1
	# …future: Turrets/Sonar/DepthCharges/Spawn — later chunks, each reading its own <Domain>Config.tres
