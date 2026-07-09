extends Node
# TEMPORARY dev harness (not part of the verify gate): walks title → tree (max level, buy a build)
# → sortie under a real renderer, saving screenshots for the C4 mockup side-by-side check.

var t: int = 0
@onready var main: Node = get_node("Main")

func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path)

func _process(_delta: float) -> void:
	t += 1
	if t == 30:
		_shot("/tmp/c4_port_title.png")
	if t == 40:
		main.dev_max_level()
		for id in ["ord1", "ord2", "ord3", "ord4", "ord5", "ord6", "sea1", "sea2", "flk1"]:
			main.profile.unlocked.append(id)
		main.show_screen("tree")
	if t == 70:
		_shot("/tmp/c4_port_tree.png")
	if t == 80:
		main.start_sortie()
		Input.action_press("helm_ahead")
	if t == 380:
		Input.action_release("helm_ahead")
	if t == 900:
		Input.warp_mouse(Vector2(880, 300))
	if t == 910:
		Input.action_press("force_fire_large")
	if t == 1080:
		_shot("/tmp/c4_port_sortie.png")
		Input.action_release("force_fire_large")
	if t >= 1085:
		get_tree().quit()
