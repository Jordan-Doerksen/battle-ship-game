class_name Hull
extends RefCounted
# C3 hull damage intake (docs/specs/wave-director.md): one pip pool (D1.8), a post-hit grace window
# (owner interview decision #4 — a refinement of the pool's behavior, not a second health layer),
# and the run end. The contact shape is a CAPSULE along the keel, matching the ×2.4 silhouette —
# ship geometry constants, not balance tunables (pips/grace live in WaveConfig).

const HALF_LEN: float = 85.0   # keel segment half-length
const RADIUS: float = 26.0     # beam radius

static func dist_to_hull(world: GameWorld, p: Vector2) -> float:
	var fwd := Vector2(sin(world.ship_heading), -cos(world.ship_heading))
	var a: Vector2 = world.ship_pos - fwd * HALF_LEN
	var ab: Vector2 = fwd * (2.0 * HALF_LEN)
	var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func damage(world: GameWorld, dmg: int, cfg: Configs) -> void:
	if world.run_over or world.elapsed < world.grace_until or world.godmode:   # godmode: DEV kit only
		return
	world.hull -= dmg
	world.grace_until = world.elapsed + cfg.waves.grace_secs
	world.effects.append({ "type": "shiphit", "pos": world.ship_pos })
	if world.hull <= 0:
		world.hull = 0
		world.run_over = true
		world.effects.append({ "type": "shipdeath", "pos": world.ship_pos })
