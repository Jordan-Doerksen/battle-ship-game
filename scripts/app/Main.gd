extends Node2D
# Root (app domain). Owns the fixed-step accumulator that drives `Sim.step`, writes the sim-side
# InputState snapshot from Godot input once per frame BEFORE stepping (the ONLY door input enters the
# sim through — see InputState.gd), and binds the render/HUD nodes to the world. No gameplay logic
# lives here (see docs/SPEC.md).

var world: GameWorld
var sim_cfg: SimConfig
var field_cfg: FieldConfig
var movement_cfg: MovementConfig
var _accum: float = 0.0
var _step: float = 1.0 / 60.0
@onready var _field: FieldRenderer = $Field
@onready var _cam: Camera2D = $Cam
@onready var _gauges: HelmGauges = $HUD/Gauges

func _ready() -> void:
	sim_cfg = load("res://config/sim.tres") as SimConfig
	if sim_cfg == null:
		sim_cfg = SimConfig.new()
	field_cfg = load("res://config/field.tres") as FieldConfig
	if field_cfg == null:
		field_cfg = FieldConfig.new()
	movement_cfg = load("res://config/movement.tres") as MovementConfig
	if movement_cfg == null:
		movement_cfg = MovementConfig.new()
	_step = 1.0 / float(sim_cfg.sim_hz)
	_cam.make_current()
	world = GameWorld.new(int(Time.get_ticks_usec()))
	_field.bind(world, field_cfg, movement_cfg)
	_gauges.bind(world, movement_cfg)

func _process(delta: float) -> void:
	# input snapshot first, then step — held-key throttle/helm, no persistent telegraph state (C1 spec)
	world.input.thrust = Input.get_axis("helm_astern", "helm_ahead")
	world.input.rudder = Input.get_axis("helm_port", "helm_starboard")
	var steps: int = 0
	_accum += delta
	while _accum >= _step and steps < sim_cfg.max_frame_catchup:
		Sim.step(world, _step, movement_cfg)
		_accum -= _step
		steps += 1
	if steps >= sim_cfg.max_frame_catchup:
		_accum = 0.0   # don't spiral-of-death catch up past the cap
	_cam.position = world.ship_pos
	_field.queue_redraw()
	_gauges.queue_redraw()
