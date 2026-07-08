class_name InputState
extends RefCounted
# Sim-side input snapshot (C1 spec). Main writes it from Godot input once per frame BEFORE stepping;
# sim systems only read it. This is the ONLY door input enters the sim through — no system may poll
# Godot's Input singleton directly (one-way boundary, DECISIONS Non-Negotiable Constraints). Probes
# script runs by writing these fields directly, which is what makes input-driven runs replayable.

var thrust: float = 0.0   # −1..1 from S/W: +1 all ahead, −1 brake-then-astern
var rudder: float = 0.0   # −1..1 from A/D: +1 clockwise on screen (D), screen-fixed even astern
