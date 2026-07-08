class_name Sim
extends RefCounted
# The deterministic step root (DECISIONS D1.4). ONE fixed-timestep tick mutates `world` in a stable,
# index-ordered sequence. Called only by Main's fixed-step accumulator — never from a render path.
# C0 has no gameplay systems yet; this only proves the clock advances deterministically. Systems slot
# into this fixed order as chunks land (naval movement first — see docs/SPEC.md C1); the order is part
# of determinism.

static func step(world: GameWorld, dt: float) -> void:
	world.elapsed += dt
	world.tick += 1
	# …future: Movement.step(world, dt, movement_cfg) — naval momentum/turning (C1)
	# …future: Turrets/Sonar/DepthCharges/Spawn — later chunks, each reading its own <Domain>Config.tres
