class_name Tech
extends RefCounted
# C4 tech application + spend rules (docs/specs/tech-tree.md). apply() derives a sortie's Configs:
# every resource is DUPLICATED, then unlocked nodes' mods run in catalog order — the base .tres
# instances are never mutated, and the same unlock set always derives the same configs (determinism
# per seed + build). The sim never sees the Profile; it sees only the derived Configs.

static func apply(base: Configs, unlocked: Array) -> Configs:
	var c := Configs.new()
	c.movement = base.movement.duplicate()
	c.hardpoints = base.hardpoints.duplicate()
	c.weapons = base.weapons.duplicate(true)
	c.waves = base.waves.duplicate()
	c.enemies = base.enemies.duplicate(true)
	c.progress = base.progress.duplicate()
	c.tech = base.tech.duplicate(true)
	c.sonar = base.sonar.duplicate()
	c.airwing = base.airwing.duplicate()
	c.terrain = base.terrain.duplicate()   # C15: the waters ride the derivation like every system
	c.bosses = base.bosses.duplicate(true)
	c.weather = base.weather.duplicate()   # C17: the fronts ride it too
	c.whirlpool = base.whirlpool.duplicate()   # C18: and the vortex
	c.ambience = base.ambience.duplicate()     # C19: render dials ride along (sim-blind)
	for node in c.tech.catalog:
		if node.locked or not unlocked.has(node.id):
			continue
		for m in node.mods:
			_apply_mod(c, m)
	return c

static func _apply_mod(c: Configs, m: Dictionary) -> void:
	var path: PackedStringArray = String(m["p"]).split(".")
	var target: Resource = null
	match path[0]:
		"move": target = c.movement
		"waves": target = c.waves
		"tech": target = c.tech
		"sonar": target = c.sonar
		"airwing": target = c.airwing
		"weapons": target = c.weapons.by_id(path[1])
		"enemies": target = c.enemies.by_id(path[1])
	if target == null:
		return
	var key: String = path[path.size() - 1]
	if m.has("set"):
		target.set(key, m["set"])
	elif m.has("mul"):
		target.set(key, target.get(key) * m["mul"])
	elif m.has("add"):
		target.set(key, target.get(key) + m["add"])

# ── spend rules: strict in-branch order, variable costs, points = (level − 1) − spent ──
static func points_spent(unlocked: Array, tech_cfg: TechConfig) -> int:
	var spent: int = 0
	for n in tech_cfg.catalog:
		if unlocked.has(n.id):
			spent += n.cost
	return spent

static func points_available(profile: Profile, tech_cfg: TechConfig, pc: ProgressConfig) -> int:
	return (pc.level_info(profile.xp)["level"] - 1) - points_spent(profile.unlocked, tech_cfg)

static func can_buy(profile: Profile, nid: String, tech_cfg: TechConfig, pc: ProgressConfig) -> bool:
	var node: TechDef = tech_cfg.by_id(nid)
	if node == null or node.locked or profile.unlocked.has(nid):
		return false
	for n in tech_cfg.catalog:   # every earlier node in the branch must be owned
		if n.id == nid:
			break
		if n.branch == node.branch and not profile.unlocked.has(n.id):
			return false
	return points_available(profile, tech_cfg, pc) >= node.cost
