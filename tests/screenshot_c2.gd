extends Node
# TEMPORARY dev harness (not part of the verify gate): drives the helm + force-fire via Input actions
# under a real renderer, then saves viewport screenshots for the C2 LOOK-LOCK side-by-side check.

var t: int = 0

func _process(_delta: float) -> void:
	t += 1
	if t == 30:
		Input.action_press("helm_ahead")
	if t == 200:
		Input.warp_mouse(Vector2(900, 250))
	if t == 210:
		Input.action_press("force_fire_all")
	if t == 380:
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/c2_port_allguns.png")
		print("SHOT1 SAVED")
		Input.action_release("force_fire_all")
		Input.action_press("helm_starboard")
		Input.warp_mouse(Vector2(380, 500))
	if t == 470:
		Input.action_press("force_fire_large")
	if t == 620:
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/c2_port_mainbattery.png")
		print("SHOT2 SAVED")
	if t >= 625:
		get_tree().quit()
