extends Node
# TEMPORARY dev harness (not part of the verify gate): sails into wave 1 under a real renderer,
# force-fires, and saves viewport screenshots for the C3 mockup side-by-side check.

var t: int = 0

func _process(_delta: float) -> void:
	t += 1
	if t == 30:
		Input.action_press("helm_ahead")
	if t == 420:
		Input.action_release("helm_ahead")
	if t == 900:
		Input.warp_mouse(Vector2(850, 300))
	if t == 910:
		Input.action_press("force_fire_all")
	if t == 1100:
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/c3_port_combat.png")
		print("SHOT1 SAVED")
		Input.action_release("force_fire_all")
	if t == 1110:   # sink the ship for the run-over card
		var main := get_node("Main")
		main.world.grace_until = 0.0
		main.world.hull = 1
		Hull.damage(main.world, 999, main.cfgs)
	if t == 1220:
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/c3_port_lost.png")
		print("SHOT2 SAVED")
	if t >= 1225:
		get_tree().quit()
