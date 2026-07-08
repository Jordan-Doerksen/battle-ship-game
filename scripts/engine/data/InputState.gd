class_name InputState
extends RefCounted
# Sim-side input snapshot (C1 spec). Main writes it from Godot input once per frame BEFORE stepping;
# sim systems only read it. This is the ONLY door input enters the sim through — no system may poll
# Godot's Input singleton directly (one-way boundary, DECISIONS Non-Negotiable Constraints). Probes
# script runs by writing these fields directly, which is what makes input-driven runs replayable.

var thrust: float = 0.0   # −1..1 from S/W: +1 all ahead, −1 brake-then-astern
var rudder: float = 0.0   # −1..1 from A/D: +1 clockwise on screen (D), screen-fixed even astern
var force_all: bool = false     # LMB held — ALL mounts on the cursor, domain tags overridden (C2)
var force_large: bool = false   # RMB held — large mounts only (never true while force_all is)
var force_medium: bool = false  # MMB held — medium mounts only (C3 gate rev 1); combines with RMB
var aim_world: Vector2 = Vector2.ZERO   # cursor in WORLD space; Main converts — sim never sees screen
