class_name HardpointConfig
extends Resource
# The hull's mount plan (docs/specs/hardpoint-hull.md, owner gate revisions): 4S/4M/2L on the ×2.4
# (~210 u) hull, hull-local coordinates with the bow at −y; the helipad (0, 65) stays clear (open
# thread #3). Instance lives at config/hardpoint.tres. Weapon stats live in WeaponConfig; this file
# is positions + the fixed C2 test loadout only.

@export var mount_pos: PackedVector2Array = PackedVector2Array([
	Vector2(0, -72), Vector2(0, 36),                       # L — centerline fore/aft, own barbettes
	Vector2(-19, -28), Vector2(19, -28),                   # M — beam, flanking the superstructure
	Vector2(-19, 14), Vector2(19, 14),
	Vector2(-16, -55), Vector2(16, -55),                   # S — sponson pairs fore / quarter
	Vector2(-17, 52), Vector2(17, 52),
])
@export var mount_size: PackedStringArray = PackedStringArray([
	"L", "L", "M", "M", "M", "M", "S", "S", "S", "S",
])
@export var loadout: Dictionary = { "S": "aa20", "M": "dp5", "L": "mb16" }   # fixed C2 test loadout
@export var aim_tol: float = 0.06   # rad — barrel alignment tolerance to fire
