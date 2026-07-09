extends Node
# TEMPORARY dev harness (not part of the verify gate): buys the AIR WING column, then captures the
# declassified tree, the bird on its escort weave, and an ASW prosecution — the C6 side-by-side.

var t: int = 0
var _shot_weave: bool = false
var _shot_drop: bool = false
@onready var main: Node = get_node("Main")

func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path)

func _place(type_id: String, pos: Vector2, hp: int) -> void:
	var def: EnemyDef = main.cfgs.enemies.by_id(type_id)
	var e := Enemy.new()
	e.type_id = def.id
	e.layer = def.layer
	e.active = true
	e.pos = main.world.ship_pos + pos
	e.heading = atan2(-pos.x, pos.y)
	e.hp_max = def.hp
	e.hp = hp
	main.world.enemies.append(e)

func _process(_delta: float) -> void:
	t += 1
	if t == 20:
		main.dev_max_level()
		for id in ["air1", "air2", "air3", "air4", "air5", "air6", "air7"]:
			main.profile.unlocked.append(id)
		main.show_screen("tree")
	if t == 50:
		_shot("/tmp/c6_port_tree.png")
	if t == 60:
		main.start_sortie()
		main.world.godmode = true
		main.world.freeze_waves = true
	if t > 120 and not _shot_weave:
		var d: float = main.world.helo_pos.distance_to(main.world.ship_pos)
		if main.world.helo_state == "air" and d < 320.0:
			_shot_weave = true
			_shot("/tmp/c6_port_weave.png")
			# feed the bird in-frame: a tough sub to prosecute + a swarmer for the door gunners
			_place("sub", Vector2(80, -230), 999999)
			_place("swarmer", Vector2(-140, -190), 999999)
	if _shot_weave and not _shot_drop:
		for p in main.world.projectiles.items:
			if p.active and p.wid == "dc" and main.world.helo_state == "air":
				_shot_drop = true
				_shot("/tmp/c6_port_drop.png")
				break
	if t >= 1400:
		if not _shot_drop:
			_shot("/tmp/c6_port_drop.png")
		get_tree().quit()
