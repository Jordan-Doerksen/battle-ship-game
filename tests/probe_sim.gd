extends SceneTree
# C0 boot probe (run with `godot --headless -s tests/probe_sim.gd`). Proves the fixed-step sim clock
# advances deterministically and the seeded Rng stream is reproducible for a fixed seed, same as
# fulfillment's probe_sim proves for its own C0. Runs with idle input (movement is exercised by
# tests/probe_movement.gd); the checks below are unchanged since C0.

func _initialize() -> void:
	var fails: int = 0
	var move_cfg := MovementConfig.new()   # class defaults mirror config/movement.tres

	var world_a := GameWorld.new(777001)
	var world_b := GameWorld.new(777001)
	for i in range(600):   # 10 sim-seconds at 60Hz
		Sim.step(world_a, 1.0 / 60.0, move_cfg)
		Sim.step(world_b, 1.0 / 60.0, move_cfg)
		world_a.rng.nextf()   # draw from both streams identically to prove replay-stability
		world_b.rng.nextf()

	print("PROBE_SIM: tick_a=%d tick_b=%d elapsed_a=%.4f elapsed_b=%.4f calls_a=%d calls_b=%d" % [
		world_a.tick, world_b.tick, world_a.elapsed, world_b.elapsed, world_a.rng.calls, world_b.rng.calls])

	fails += _check(world_a.tick == 600, "sim ticked 600 times (tick=%d)" % world_a.tick)
	fails += _check(is_equal_approx(world_a.elapsed, 10.0), "sim clock reached 10s (elapsed=%.4f)" % world_a.elapsed)
	fails += _check(world_a.tick == world_b.tick and world_a.elapsed == world_b.elapsed,
		"two worlds on the same seed stay in lockstep")
	fails += _check(world_a.rng.calls == world_b.rng.calls,
		"rng draw-count tripwire matches across identical seeds")

	if fails == 0:
		print("PROBE_SIM PASSED")
	else:
		print("PROBE_SIM FAILED (%d check(s))" % fails)
	quit(fails)

func _check(cond: bool, label: String) -> int:
	print(("  OK  " if cond else "  FAIL") + " — " + label)
	return 0 if cond else 1
