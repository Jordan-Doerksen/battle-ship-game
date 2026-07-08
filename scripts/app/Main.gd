extends Node2D
# Root (app domain) — C0 Heartbeat only. Owns the fixed-step accumulator that drives `Sim.step` and
# binds the renderer to the world. No gameplay lives here; this proves the loop, the seeded RNG, and
# the one-way sim→render split are alive before any system is built (see docs/SPEC.md C0).

var world: GameWorld
var sim_cfg: SimConfig
var field_cfg: FieldConfig
var _accum: float = 0.0
var _step: float = 1.0 / 60.0
@onready var _field: FieldRenderer = $Field
@onready var _cam: Camera2D = $Cam

func _ready() -> void:
	sim_cfg = load("res://config/sim.tres") as SimConfig
	if sim_cfg == null:
		sim_cfg = SimConfig.new()
	field_cfg = load("res://config/field.tres") as FieldConfig
	if field_cfg == null:
		field_cfg = FieldConfig.new()
	_step = 1.0 / float(sim_cfg.sim_hz)
	_cam.make_current()
	world = GameWorld.new(int(Time.get_ticks_usec()))
	_field.bind(world, field_cfg)

func _process(delta: float) -> void:
	var steps: int = 0
	_accum += delta
	while _accum >= _step and steps < sim_cfg.max_frame_catchup:
		Sim.step(world, _step)
		_accum -= _step
		steps += 1
	if steps >= sim_cfg.max_frame_catchup:
		_accum = 0.0   # don't spiral-of-death catch up past the cap
	_cam.position = world.ship_pos
	_field.queue_redraw()
