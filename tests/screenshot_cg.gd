extends Node
# TEMPORARY dev harness (not part of the verify gate): anchors two gunboats close aboard and lets
# the crewed MGs strafe — the CREWED GUNS proof shot (burst tracers + stitch-lines on the water).

const OUT := "C:/Users/Doerk/AppData/Local/Temp/claude/C--projects/16634eea-72ab-4d6d-a258-f38bc2e50372/scratchpad/"

var t: int = 0
@onready var main: Node = get_node("Main")

func _place(type_id: String, pos: Vector2) -> void:
	var def: EnemyDef = main.cfgs.enemies.by_id(type_id)
	var e := Enemy.new()
	e.type_id = def.id
	e.layer = def.layer
	e.active = true
	e.pos = main.world.ship_pos + pos
	e.heading = 0.0
	e.hp_max = def.hp
	e.hp = 999999
	main.world.enemies.append(e)

func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path)

func _process(_delta: float) -> void:
	t += 1
	if t == 20:
		main.start_sortie()
		main.world.godmode = true
		main.world.freeze_waves = true
		main.cfgs.enemies.by_id("gunboat").speed = 0.0
		main.cfgs.enemies.by_id("gunboat").fire_period = 1e9   # they hold fire; the MGs talk
		_place("gunboat", Vector2(230, -180))
		_place("gunboat", Vector2(-260, 90))
	if t == 210 or t == 250 or t == 290:
		_shot(OUT + "cg_strafe_%d.png" % t)
	if t >= 295:
		get_tree().quit()
