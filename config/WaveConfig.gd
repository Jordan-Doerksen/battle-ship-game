class_name WaveConfig
extends Resource
# C3 wave-director tunables (docs/specs/wave-director.md — the seeded budget director), plus the
# hull pool and the radar scope reach (gate revision 1; the sonar chunk will sit beside it).
# Instance lives at config/waves.tres. Per the config-split rule, enemy stats live in EnemyConfig.

@export var base_budget: int = 6          # wave 1 threat points
@export var budget_per_wave: int = 4      # added points per wave
@export var lull_secs: float = 8.0        # breather between waves (future shop window)
@export var first_wave_delay: float = 3.0 # seconds before wave 1 arrives
@export var spawn_ring_min: float = 1700.0  # arrival distance — beyond the view edge
@export var spawn_ring_max: float = 2000.0
@export var cluster_min: int = 1          # attack bearings per wave (seeded)
@export var cluster_max: int = 3
@export var hull_pips: int = 10           # run health (D1.8: one pool, pip-style)
@export var grace_secs: float = 0.8       # post-hit invulnerability window
@export var radar_range: float = 2200.0   # scope reach — covers the spawn ring
