class_name ProgressConfig
extends Resource
# C4 XP + level curve (docs/specs/tech-tree.md). Instance lives at config/progress.tres. Per the
# config-split rule this holds progression tunables ONLY; the tech catalog is TechConfig.

@export var xp_swarmer: int = 10        # per kill, by enemy type
@export var xp_gunboat: int = 30
@export var xp_bomber: int = 50
@export var xp_wave_bonus: int = 25     # × wave number, banked on each clear
@export var level_xp_base: int = 150    # XP for level 1 → 2
@export var level_xp_step: int = 100    # added per subsequent level (linear ramp)

func xp_for_kill(type_id: String) -> int:
	match type_id:
		"swarmer": return xp_swarmer
		"gunboat": return xp_gunboat
		"bomber": return xp_bomber
	return 0

func xp_for_next(level: int) -> int:
	return level_xp_base + level_xp_step * (level - 1)

# total XP → { level, into (XP into the current level), next (XP needed for the next) }
func level_info(total_xp: int) -> Dictionary:
	var level: int = 1
	var spent: int = 0
	while total_xp - spent >= xp_for_next(level):
		spent += xp_for_next(level)
		level += 1
	return { "level": level, "into": total_xp - spent, "next": xp_for_next(level) }
