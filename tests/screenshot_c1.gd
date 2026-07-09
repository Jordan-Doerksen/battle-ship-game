extends Node
# TEMPORARY dev harness (not part of the verify gate): drives the helm via Input actions for a few
# seconds under a real renderer, then saves a viewport screenshot for the mockup side-by-side check.

var t: int = 0

func _process(_delta: float) -> void:
	t += 1
	if t == 30:
		Input.action_press("helm_ahead")
	if t == 300:
		Input.action_press("helm_starboard")
	if t == 480:
		var img := get_viewport().get_texture().get_image()
		img.save_png("/tmp/c1_screenshot.png")
		print("SCREENSHOT SAVED")
	if t >= 485:
		get_tree().quit()
