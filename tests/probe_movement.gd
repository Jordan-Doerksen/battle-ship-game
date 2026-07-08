extends SceneTree
# C1 acceptance probe (run with `godot --headless -s tests/probe_movement.gd`) — the seven checks from
# docs/specs/naval-movement.md §Acceptance, run headless against the real Sim/Movement code with the
# real config/movement.tres values. Input is scripted by writing world.input directly, exactly the way
# Main does — proving input-driven runs are replayable.

const DT: float = 1.0 / 60.0

var cfg: MovementConfig

func _initialize() -> void:
	var fails: int = 0
	cfg = load("res://config/movement.tres") as MovementConfig
	if cfg == null:
		cfg = MovementConfig.new()

	# 1 — determinism: same seed + same scripted input => identical state; movement adds ZERO rng draws
	var wa := GameWorld.new(424242)
	var wb := GameWorld.new(424242)
	var wi := GameWorld.new(424242)   # input-idle reference for the rng tripwire
	for i in range(600):
		var th: float = 1.0 if i < 200 else (-1.0 if i < 400 else 0.0)
		var ru: float = 1.0 if i % 120 < 60 else -1.0
		wa.input.thrust = th; wa.input.rudder = ru
		wb.input.thrust = th; wb.input.rudder = ru
		Sim.step(wa, DT, cfg)
		Sim.step(wb, DT, cfg)
		Sim.step(wi, DT, cfg)
	fails += _check(wa.ship_pos == wb.ship_pos and wa.ship_vel == wb.ship_vel and wa.ship_heading == wb.ship_heading,
		"determinism: 600 scripted ticks leave two worlds byte-identical")
	fails += _check(wa.rng.calls == wb.rng.calls and wa.rng.calls == wi.rng.calls,
		"determinism: rng.calls identical to the input-idle count (movement draws no RNG; calls=%d)" % wa.rng.calls)

	# 2 — accel: from rest, full W reaches >=95% of max between 3.5s and 5.5s
	var w := GameWorld.new(1)
	var t95: float = -1.0
	for i in range(int(8.0 / DT)):
		w.input.thrust = 1.0
		Sim.step(w, DT, cfg)
		if t95 < 0.0 and Movement.keel_speeds(w).x >= 0.95 * cfg.max_speed_ahead:
			t95 = w.elapsed
	fails += _check(t95 >= 3.5 and t95 <= 5.5, "accel: 95%% of full ahead at t=%.2fs (window 3.5–5.5)" % t95)

	# 3 — coast: throttle off at full speed; after 5s idle, speed still > 50% of max
	w = GameWorld.new(1)
	_run(w, 1.0, 0.0, 12.0)
	_run(w, 0.0, 0.0, 5.0)
	var coast_frac: float = w.ship_vel.length() / cfg.max_speed_ahead
	fails += _check(coast_frac > 0.5, "coast: %.1f%% of max after 5s idle (long coast)" % (coast_frac * 100.0))

	# 4 — brake + reverse: S from full ahead stops markedly faster than coasting, then caps astern within 2%
	w = GameWorld.new(1)
	_run(w, 1.0, 0.0, 12.0)
	var t_stop: float = -1.0
	var t0: float = w.elapsed
	for i in range(int(20.0 / DT)):
		w.input.thrust = -1.0
		Sim.step(w, DT, cfg)
		if t_stop < 0.0 and Movement.keel_speeds(w).x <= 0.0:
			t_stop = w.elapsed - t0
	var astern_cap: float = cfg.max_speed_ahead * cfg.astern_frac
	var cap_err: float = absf(-Movement.keel_speeds(w).x - astern_cap) / astern_cap
	fails += _check(t_stop > 0.0 and t_stop < 4.0,
		"brake: full ahead to stop in %.2fs (coast alone stays >50%% after 5s)" % t_stop)
	fails += _check(cap_err < 0.02,
		"reverse: astern settles %.1f vs cap %.1f (%.2f%% off, <2%%)" % [-Movement.keel_speeds(w).x, astern_cap, cap_err * 100.0])

	# 5 — turn floor: at a standstill, full rudder still turns at >= floor * max rate
	w = GameWorld.new(1)
	_run(w, 0.0, 1.0, 2.0)
	var rate: float = w.ship_heading / 2.0
	fails += _check(rate >= cfg.turn_speed_floor * cfg.turn_rate_max - 1e-9,
		"turn floor: %.4f rad/s at standstill (floor %.4f)" % [rate, cfg.turn_speed_floor * cfg.turn_rate_max])

	# 6 — slip: sustained full-speed full-rudder turn shows real lateral velocity, decaying when centered
	w = GameWorld.new(1)
	_run(w, 1.0, 0.0, 12.0)
	_run(w, 1.0, 1.0, 4.0)
	var slip_mid: float = absf(Movement.keel_speeds(w).y)
	_run(w, 1.0, 0.0, 3.0)
	var slip_after: float = absf(Movement.keel_speeds(w).y)
	fails += _check(slip_mid > 20.0 and slip_after < slip_mid * 0.2,
		"slip: %.1f u/s cross-keel mid-turn, %.1f after centering" % [slip_mid, slip_after])

	if fails == 0:
		print("PROBE_MOVEMENT PASSED")
	else:
		print("PROBE_MOVEMENT FAILED (%d check(s))" % fails)
	quit(fails)

func _run(w: GameWorld, thrust: float, rudder: float, secs: float) -> void:
	for i in range(int(round(secs / DT))):
		w.input.thrust = thrust
		w.input.rudder = rudder
		Sim.step(w, DT, cfg)

func _check(cond: bool, label: String) -> int:
	print(("  OK  " if cond else "  FAIL") + " — " + label)
	return 0 if cond else 1
