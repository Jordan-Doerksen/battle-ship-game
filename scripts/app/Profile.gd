class_name Profile
extends RefCounted
# The commander's persistent career (C4) — total XP and unlocked tech node ids. THE first save file:
# user://profile.cfg. Strictly meta-layer: Main banks world.xp_run here at run end and derives the
# next sortie's Configs from it via Tech.apply; the sim itself never reads the profile.

const PATH := "user://profile.cfg"

var xp: int = 0
var unlocked: Array = []   # tech node id strings, in purchase order

static func load_profile(path: String = PATH) -> Profile:
	var p := Profile.new()
	var f := ConfigFile.new()
	if f.load(path) == OK:
		p.xp = int(f.get_value("career", "xp", 0))
		var u: Array = f.get_value("career", "unlocked", [])
		for id in u:
			p.unlocked.append(String(id))
	return p

func save(path: String = PATH) -> void:
	var f := ConfigFile.new()
	f.set_value("career", "xp", xp)
	f.set_value("career", "unlocked", unlocked)
	f.save(path)

func respec() -> void:
	unlocked.clear()
	save()
