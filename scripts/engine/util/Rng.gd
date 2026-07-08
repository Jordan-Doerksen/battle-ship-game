class_name Rng
extends RefCounted
# Seeded deterministic RNG — the ONLY randomness in the sim (DECISIONS D1.4). Backed by Godot's native
# RandomNumberGenerator (PCG32): same seed + same draw order => same run (dailies / replay / one-line
# repro).
#
# `calls` is a determinism tripwire, NOT part of the stream: two runs on one seed must show identical
# draw counts at the same sim time. Cosmetics (starfield, etc.) use their OWN generators — they must
# never draw from this stream (that would let cosmetic changes shift gameplay).

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var calls: int = 0

func _init(seed_val: int) -> void:
	_rng.seed = seed_val

# Next float in [0, 1). randi() is a full 32-bit draw; /2^32 keeps the top end exclusive.
func nextf() -> float:
	calls += 1
	return float(_rng.randi()) / 4294967296.0

# Float in [lo, hi).
func rangef(lo: float, hi: float) -> float:
	return lo + (hi - lo) * nextf()

# Integer in [lo, hi] inclusive.
func rand_int(lo: int, hi: int) -> int:
	return int(floor(lo + (hi - lo + 1) * nextf()))
