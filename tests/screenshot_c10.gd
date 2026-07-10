extends Node
# TEMPORARY dev harness (not part of the verify gate): proves the C10 tactical zoom in the real
# engine — boots at home (0.51), lets wave 1's swarmers arrive (the min-size-floor stress case),
# then shoots the floor (0.40) and the LOOK-LOCKED max (0.85). Zoom is driven through the same
# _target_zoom the wheel uses, so the lerp path is exercised too.

const OUT := "C:/Users/Doerk/AppData/Local/Temp/claude/C--projects/16634eea-72ab-4d6d-a258-f38bc2e50372/scratchpad/"

var t: int = 0
@onready var main: Node = get_node("Main")

func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path)

func _process(_delta: float) -> void:
	t += 1
	if t == 20:
		main.start_sortie()
		main.world.godmode = true
		Input.action_press("helm_ahead")
	if t == 500:   # wave 1 swarmers in and engaged, AA talking
		_shot(OUT + "c10_home_051.png")
		main._target_zoom = 0.4
	if t == 580:
		_shot(OUT + "c10_floor_040.png")
		main._target_zoom = 0.85
	if t == 660:
		_shot(OUT + "c10_max_085.png")
	if t >= 665:
		get_tree().quit()
