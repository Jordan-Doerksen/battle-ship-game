class_name Mount
extends RefCounted
# Runtime state of one hardpoint mount (C2). The mount PLAN (position/size/loadout) is
# HardpointConfig; this is only what changes per tick. `ang` is the barrel's WORLD angle — turrets
# hold their aim while the hull swings under them (D1.7: hull facing never gates fire; only
# traverse time does).

var ang: float = 0.0
var cool: float = 0.0
var bloom: float = 0.0         # sustained-fire spread widening (AA texture; see WeaponDef)
var burst_left: int = 0        # rounds left in the current crewed-MG burst (CREWED GUNS CR)
var mode: String = "stow"      # stow | auto | forced — render reads it for the force-fire tint
