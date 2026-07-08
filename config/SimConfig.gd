class_name SimConfig
extends Resource
# Fixed-step clock tunables only. Instance lives at config/sim.tres.
#
# CONFIG SPLIT RULE (DECISIONS, Non-Negotiable Constraints): one small `Resource` per system domain,
# never a single monolithic balance file. Tuning naval movement should mean opening
# `config/movement.tres` and reading a ~10-line script — not scrolling a shared 300-line file that also
# holds sonar and hardpoint costs. Add a new `<Domain>Config.gd` + `.tres` when a new system lands
# (movement, hardpoints, sonar, depth-charges, …); do not grow this file to cover them.

@export var sim_hz: int = 60
@export var max_frame_catchup: int = 5
