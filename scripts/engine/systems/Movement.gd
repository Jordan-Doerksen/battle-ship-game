class_name Movement
extends RefCounted
# C1 naval movement — system #1 in Sim.step's fixed order (docs/specs/naval-movement.md, owner-approved
# via the design/naval-movement.html mockup gate). Pure arithmetic, NO RNG: the determinism tripwire
# (`world.rng.calls`) must be byte-identical whether the ship moves or idles.
#
# Heading drives velocity — never `heading = vel.angle()` (fulfillment's arcade anti-pattern this chunk
# exists to replace). The keel re-aims each tick while velocity lags behind; the leftover cross-keel
# component IS the lateral slip that makes the hull read heavy. Heading 0 = north (screen up, −Y),
# positive = clockwise, matching the north-up fixed camera.

static func step(world: GameWorld, dt: float, cfg: MovementConfig) -> void:
	var inp: InputState = world.input

	# 1. Helm — turn authority couples to speed with a floor: the ship always answers,
	#    just sluggishly when slow. Screen-fixed: D is clockwise even astern.
	var speed: float = world.ship_vel.length()
	var authority: float = maxf(cfg.turn_speed_floor, minf(1.0, speed / cfg.max_speed_ahead))
	world.ship_heading += cfg.turn_rate_max * authority * inp.rudder * dt

	# 2. Decompose velocity on the NEW keel axes.
	var fwd := Vector2(sin(world.ship_heading), -cos(world.ship_heading))
	var right := Vector2(-fwd.y, fwd.x)
	var along: float = world.ship_vel.dot(fwd)
	var lat: float = world.ship_vel.dot(right)

	# 3. Throttle — one continuous control: braking (order opposing keel motion) bites harder
	#    than thrust, and S carries smoothly through the stop into astern (no re-press gate).
	if inp.thrust != 0.0:
		var opposing: bool = (inp.thrust > 0.0 and along < -0.01) or (inp.thrust < 0.0 and along > 0.01)
		along += (cfg.brake_accel if opposing else cfg.thrust_accel) * inp.thrust * dt

	# 4. Anisotropic exponential water drag — long coast along the keel, strong-but-finite
	#    lateral drag so slip decays but visibly exists.
	along *= exp(-cfg.drag_forward * dt)
	lat *= exp(-cfg.drag_lateral * dt)

	# 5. Hull speed caps.
	along = clampf(along, -cfg.max_speed_ahead * cfg.astern_frac, cfg.max_speed_ahead)

	# 6. Recompose and integrate.
	world.ship_vel = fwd * along + right * lat
	world.ship_pos += world.ship_vel * dt

# Along-keel / cross-keel decomposition for read-only consumers (HUD gauges, probes). Pure function of
# world state — deriving it here keeps GameWorld carrying only true state.
static func keel_speeds(world: GameWorld) -> Vector2:
	var fwd := Vector2(sin(world.ship_heading), -cos(world.ship_heading))
	return Vector2(world.ship_vel.dot(fwd), world.ship_vel.dot(Vector2(-fwd.y, fwd.x)))
