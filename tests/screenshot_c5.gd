extends Node
# TEMPORARY dev harness (not part of the verify gate): drives a sortie with subs planted around the
# ship, saving screenshots for the C5 mockup side-by-side check — detected silhouette + contact
# diamond + DC volley, the underwater blasts, a torpedo wake, and the six-column tree.

var t: int = 0
@onready var main: Node = get_node("Main")

func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path)

func _place_sub(pos: Vector2, hp: int) -> void:
	var def: EnemyDef = main.cfgs.enemies.by_id("sub")
	var e := Enemy.new()
	e.type_id = def.id
	e.layer = def.layer
	e.active = true
	e.pos = main.world.ship_pos + pos
	e.heading = atan2(-pos.x, pos.y)   # facing the ship
	e.hp_max = def.hp
	e.hp = hp
	main.world.enemies.append(e)

func _process(_delta: float) -> void:
	t += 1
	if t == 20:
		main.show_screen("tree")
	if t == 50:
		_shot("/tmp/c5_port_tree.png")
	if t == 60:
		main.start_sortie()
		main.world.godmode = true
		main.world.freeze_waves = true
		_place_sub(Vector2(60, 150), 999999)    # astern quarter — detected, volleyed
		_place_sub(Vector2(320, -520), 999999)  # standoff — undetected, torpedoes inbound
	if t == 130:   # ~1.2s in: contact ping fresh, charges sinking
		_shot("/tmp/c5_port_volley.png")
	if t == 165:   # fuse (1.5s) just popped — underwater blasts mid-bloom
		_shot("/tmp/c5_port_blast.png")
	if t == 540:   # torpedo wake crawling in
		_shot("/tmp/c5_port_torpedo.png")
	if t >= 545:
		get_tree().quit()
