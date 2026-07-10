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
var wid: String = ""           # weapon id ("hostile" for enemy shells), render reads it for style
var hostile: bool = false      # true = enemy shell: tests the hull capsule, not enemies (C3)
var aerial: bool = false       # C15 land rule: flying ordnance (air-layer shots, bay bombs) crosses
                               # terrain; reset at the release site in Projectiles.gd — spawners
                               # outside C15's reach (Turrets, AirWing) never write it
