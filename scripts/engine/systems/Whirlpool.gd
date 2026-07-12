class_name Whirlpool
extends RefCounted
# C18 THE WHIRLPOOL (docs/specs/whirlpools.md) — every strait has THE whirlpool: one charted,
# seeded vortex at an island constriction. NOT a Sim.step system — the field is a pure analytic
# function of position + wave count that Movement/Enemies/Projectiles query (the C15 terrain
# idiom: an unset vortex no-ops every query, so pre-C18 probes never notice).
#
# DETERMINISM: placement rolls on a DEDICATED substream (fallback path only — the constriction
# score itself is pure geometry over seed-pure terrain); the field makes ZERO draws ever. Same
# seed ⇒ same vortex, same tide, however you fought.

const SUBSTREAM_XOR: int = 0x57503138   # "WP18" — the placement stream key

# Chart the vortex: the NARROWEST navigable constriction between terrain features, min-distance
# from the ship's opening water; open-water fallback (a charted eddy) when no pinch qualifies.
static func generate(world: GameWorld, cfg: Configs) -> void:
	world.vortex_pos = Vector2.INF
	var wc: WhirlpoolConfig = cfg.whirlpool
	if not wc.enabled or wc.count < 1:
		return
	var best_gap: float = INF
	var best_mid: Vector2 = Vector2.INF
	for i in range(world.terrain.size()):
		for j in range(i + 1, world.terrain.size()):
			var a: Dictionary = world.terrain[i]
			var b: Dictionary = world.terrain[j]
			var d: float = a["pos"].distance_to(b["pos"])
			var gap: float = d - float(a["r"]) - float(b["r"])
			if gap < wc.nav_min or gap > wc.nav_max or d < 1.0:
				continue
			var u: Vector2 = (b["pos"] - a["pos"]) / d
			var mid: Vector2 = a["pos"] + u * (float(a["r"]) + gap * 0.5)   # midpoint of the water gap
			if mid.distance_to(world.ship_pos) < wc.start_clear:
				continue
			if gap < best_gap:
				best_gap = gap
				best_mid = mid
	if best_mid == Vector2.INF:   # no qualifying pinch — chart an open-water eddy off the substream
		var wr := Rng.new((int(world.world_seed) ^ SUBSTREAM_XOR) & 0xFFFFFFFF)
		for k in range(40):
			var ang: float = wr.nextf() * TAU
			var dist: float = wc.start_clear + 150.0 + wr.nextf() * 400.0
			var p: Vector2 = world.ship_pos + Vector2(sin(ang), -cos(ang)) * dist
			if Terrain.clear_of(world, p, wc.radius * 0.5):
				best_mid = p
				break
	world.vortex_pos = best_mid

# The tide clock (owner fork 3): a pure cosine cycle of the WAVE COUNT — floor at wave 0, full
# churn at period/2. Deterministic by construction; the radio calls the transitions.
static func tide(world: GameWorld, cfg: Configs) -> float:
	var per: int = maxi(2, cfg.whirlpool.tide_period)
	var t: float = float(world.wave % per) / float(per)
	return cfg.whirlpool.tide_floor + (1.0 - cfg.whirlpool.tide_floor) * 0.5 * (1.0 - cos(TAU * t))

# The field (u/s² before mass tiers): clockwise swirl dominating a CAPPED inward pull, smoothstep
# falloff from the rim, everything × the tide. Zero rng; Vector2.ZERO outside the influence circle.
static func field(world: GameWorld, cfg: Configs, pos: Vector2) -> Vector2:
	if world.vortex_pos.x == INF:
		return Vector2.ZERO
	var wc: WhirlpoolConfig = cfg.whirlpool
	var off: Vector2 = pos - world.vortex_pos
	var d: float = off.length()
	if d >= wc.radius or d < 1.0:
		return Vector2.ZERO
	var n: Vector2 = off / d
	var k: float = pow(1.0 - d / wc.radius, 1.35)   # gentle rim, firmer core — the cap, not an asymptote
	return (Vector2(-n.y, n.x) * wc.tang - n * wc.inward) * k * tide(world, cfg)

static func in_core(world: GameWorld, cfg: Configs, pos: Vector2) -> bool:
	if world.vortex_pos.x == INF:
		return false
	return pos.distance_to(world.vortex_pos) <= cfg.whirlpool.radius * cfg.whirlpool.core_frac
