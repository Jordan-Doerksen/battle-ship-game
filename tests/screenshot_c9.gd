extends Node
# TEMPORARY dev harness (not part of the verify gate): steams the ship and feeds straddle splash
# events for the C9 mockup side-by-side (living sea, wake, columns), then the 0.4x zoom floor,
# then reduced motion. Splash events are appended exactly as the sim emits them — same channel.

const OUT := "C:/Users/Doerk/AppData/Local/Temp/claude/C--projects/16634eea-72ab-4d6d-a258-f38bc2e50372/scratchpad/"

var t: int = 0
@onready var main: Node = get_node("Main")

func _shot(path: String) -> void:
	get_viewport().get_texture().get_image().save_png(path)
	print("SHOT " + path)

func _straddle() -> void:
	var sp: Vector2 = main.world.ship_pos
	var fwd := Vector2(sin(main.world.ship_heading), -cos(main.world.ship_heading))
	var rgt := Vector2(-fwd.y, fwd.x)
	main.world.effects.append({ "type": "splash", "pos": sp + fwd * 260.0 + rgt * 90.0, "r": 36.0 })
	main.world.effects.append({ "type": "splash", "pos": sp + fwd * 210.0 - rgt * 120.0, "r": 36.0 })
	main.world.effects.append({ "type": "splash", "pos": sp + fwd * 60.0 + rgt * 150.0, "r": 16.0, "hostile": true })
	main.world.effects.append({ "type": "splash", "pos": sp - fwd * 80.0 - rgt * 170.0, "r": 16.0, "hostile": true })
	for k in range(3):
		main.world.effects.append({ "type": "gunsplash", "pos": sp + fwd * (120.0 - k * 24.0) + rgt * (200.0 - k * 8.0) })

func _process(_delta: float) -> void:
	t += 1
	if t == 20:
		main.start_sortie()
		main.world.godmode = true
		main.world.freeze_waves = true
		Input.action_press("helm_ahead")   # steam ahead — the wake needs way on
	if t > 40 and t % 45 == 0 and t < 400:
		_straddle()
	if t == 260:
		_shot(OUT + "c9_port_sea.png")
	if t == 270:
		main.get_node("Cam").zoom = Vector2(0.4, 0.4)   # the C10 floor preview
	if t == 350:
		_shot(OUT + "c9_port_zoom04.png")
	if t == 360:
		main.field_cfg.reduced_motion = true   # the law: sea freezes, discs stay
	if t == 420:
		_shot(OUT + "c9_port_reduced.png")
	if t >= 425:
		get_tree().quit()
