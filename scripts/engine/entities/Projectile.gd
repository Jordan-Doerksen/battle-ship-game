class_name Projectile
extends RefCounted
# In-flight shell (C2). Pooled via engine/util/Pool (first real Pool consumer) — exposes the
# _idx/active/uid trio Pool requires. `life` is remaining flight seconds; splash shells burst when
# it expires (they are aimed at a point), direct shells just die at max range.

var _idx: int = 0
var uid: int = 0
var active: bool = false
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var dmg: int = 1
var splash: float = 0.0
var life: float = 0.0
var wid: String = ""           # weapon id, render reads it for tracer style
