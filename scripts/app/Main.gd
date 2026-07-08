extends Node2D
# Root (app domain). Owns the fixed-step accumulator that drives `Sim.step`, writes the sim-side
# InputState snapshot from Godot input once per frame BEFORE stepping (the ONLY door input enters the
# sim through — see InputState.gd; the mouse enters as a WORLD-space point, the sim never sees screen
# coordinates), plumbs the sim's effect batch to the renderer after stepping, and binds render/HUD
# nodes to the world. No gameplay logic lives here (see docs/SPEC.md).

var world: GameWorld
var sim_cfg: SimConfig
var field_cfg: FieldConfig
var cfgs: Configs
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
	cfgs = Configs.load_all()
	_step = 1.0 / float(sim_cfg.sim_hz)
	_cam.make_current()
	world = GameWorld.new(int(Time.get_ticks_usec()))
	_field.bind(world, field_cfg, cfgs)
	_gauges.bind(world, cfgs.movement)

func _process(delta: float) -> void:
	# input snapshot first, then step — held-key throttle/helm + hold-only force-fire (C2 spec)
	world.input.thrust = Input.get_axis("helm_astern", "helm_ahead")
	world.input.rudder = Input.get_axis("helm_port", "helm_starboard")
	var all_guns: bool = Input.is_action_pressed("force_fire_all")
	world.input.force_all = all_guns
	world.input.force_large = Input.is_action_pressed("force_fire_large") and not all_guns
	world.input.aim_world = get_global_mouse_position()
	var steps: int = 0
	_accum += delta
	while _accum >= _step and steps < sim_cfg.max_frame_catchup:
		Sim.step(world, _step, cfgs)
		_accum -= _step
		steps += 1
	if steps >= sim_cfg.max_frame_catchup:
		_accum = 0.0   # don't spiral-of-death catch up past the cap
	_field.consume_effects(world.effects)   # one-way effect plumbing: sim wrote, render consumes,
	world.effects.clear()                   # the app layer clears — renderer never touches the world
	_cam.position = world.ship_pos
	_field.queue_redraw()
	_gauges.queue_redraw()
