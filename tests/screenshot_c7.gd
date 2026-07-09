extends Node
# TEMPORARY dev harness (not part of the verify gate): spawns THE JUGGERNAUT and THE MAW pinned
# in frame for the C7 mockup side-by-side (PRIORITY plate, parts, breach, name tally).

var t: int = 0
@onready var main: Node = get_node("Main")

func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path)

func _pin_boss(rung: int, off: Vector2) -> void:
	var def: BossDef = main.cfgs.bosses.defs[rung]
	var b := Boss.new()
	b.rung = rung
	b.lap = 1
	b.pos = main.world.ship_pos + off
	b.core = def.core_hp
	b.core_max = def.core_hp
	for pd in def.parts:
		b.parts.append({ "hp": pd["hp"], "max": pd["hp"], "dead": false, "cool": 0.0 })
	b.submerged = def.id == "maw"
	main.world.boss = b
	main.cfgs.bosses.defs[rung].speed = 0.0   # pinned for the camera
	if main.world.wave_state == "lull":
		main.world.wave_state = "fighting"

func _process(_delta: float) -> void:
	t += 1
	if t == 20:
		main.start_sortie()
		main.world.godmode = true
		main.world.freeze_waves = true
	if t == 30:
		_pin_boss(0, Vector2(40, -250))
	if t == 190:   # batteries talking, parts falling, plate live
		_shot("/tmp/c7_port_juggernaut.png")
	if t == 200:
		main.world.boss = null
		for e in main.world.enemies:
			e.active = false
		_pin_boss(2, Vector2(60, -280))
	if t == 330:   # submerged stalk — ripple field + torpedo fans
		_shot("/tmp/c7_port_maw_sub.png")
		main.world.boss.cycle_t = 1e9   # force the breach
	if t == 430:
		_shot("/tmp/c7_port_maw_breach.png")
	if t >= 435:
		get_tree().quit()
