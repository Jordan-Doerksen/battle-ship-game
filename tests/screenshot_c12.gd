extends Node
# TEMPORARY dev harness (not part of the verify gate): C12 + play-test-tune proofs — the attract
# battle under the title (scrim + action), then a sortie's cleaned-up scope (ring labels, RACKS
# readout on the plate) with a hint plate up.

const OUT := "C:/Users/Doerk/AppData/Local/Temp/claude/C--projects/16634eea-72ab-4d6d-a258-f38bc2e50372/scratchpad/"

var t: int = 0
@onready var main: Node = get_node("Main")

func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path)

func _process(_delta: float) -> void:
	t += 1
	if t == 1500:   # the attract war has waves on screen by now
		_shot(OUT + "tune_title_attract.png")
	if t == 1510:
		main.start_sortie()
		main.world.godmode = true
		Input.action_press("helm_ahead")
	if t == 1800:   # helm hint plate up (first-profile drip), scope labeled, racks armed
		_shot(OUT + "tune_scope_hud.png")
	if t >= 1805:
		get_tree().quit()
