extends Node
# TEMPORARY dev harness (not part of the verify gate): C13 proofs — the cranked attract title
# (full tree, godmode, crowded ocean) and two FIELD MANUAL pages. No sortie is started, so the
# real profile's drip hints stay un-consumed.

const OUT := "C:/Users/Doerk/AppData/Local/Temp/claude/C--projects/16634eea-72ab-4d6d-a258-f38bc2e50372/scratchpad/"

var t: int = 0
@onready var main: Node = get_node("Main")

func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path)

func _process(_delta: float) -> void:
	t += 1
	if t == 1100:   # ~18s in: the show-off war is crowded, wave 2-3 fielded
		_shot(OUT + "c13_title_attract.png")
	if t == 1110:
		main._open_manual()
	if t == 1300:   # page 1, mid-loop
		_shot(OUT + "c13_manual_p1.png")
	if t == 1310:
		for k in range(4):   # flip to page 5 — THE DEEP
			main._manual.flip(1)
	if t == 1550:
		_shot(OUT + "c13_manual_p5.png")
	if t >= 1555:
		get_tree().quit()
