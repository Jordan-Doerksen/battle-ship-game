extends Node
# TEMPORARY dev harness (not part of the verify gate): C16 proof — a sortie fought long enough
# to show the vanguard, then the main body landing, with the wave-plate naming the echelon phase.

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
		main.cfgs.waves.first_wave_delay = 1.0    # the next wave comes quickly
		main.cfgs.bosses.every_n = 0              # no machine — the echelon staging is the subject
		main.world.wave = 5                       # jump to wave 6: main-echelon templates have unlocked
		main.world.lull_until = main.world.elapsed + 1.0
		main._target_zoom = 0.40                  # pull out so the formations read
		# hold station — the ship sits so the echelons converge on-camera
	if t == 340:    # ~5s: wave 1 vanguard on the water
		_shot(OUT + "c16_vanguard.png")
	if t == 1180:   # ~19s: the main body has landed (+15s echelon)
		_shot(OUT + "c16_mainbody.png")
	if t >= 1185:
		get_tree().quit()
