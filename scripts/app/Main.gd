extends Node2D
# Root (app domain). Owns the fixed-step accumulator, the C4 state machine (title / tree / game),
# the persistent Profile (banked at run end; the sim never reads it), and the InputState snapshot —
# still the ONLY door input enters the sim through. Each sortie derives its Configs from the base
# .tres values + the profile's unlocked tech (Tech.apply) BEFORE the world is created, so
# determinism per (seed, unlock set) holds. The DEV test kit exists only in debug builds.

var world: GameWorld
var sim_cfg: SimConfig
var field_cfg: FieldConfig
var base_cfgs: Configs
var cfgs: Configs
var profile: Profile
var god_guns: bool = false        # DEV kit weapon override, rebuilt into cfgs per toggle/sortie
var state: String = "title"       # title | tree | game
var _accum: float = 0.0
var _step: float = 1.0 / 60.0
var _banked: bool = false
var _banked_xp: int = 0           # this run's XP already in the profile (posthumous kills bank the delta)
var _level_before_bank: int = 1   # career level when this run's banking began (for the LEVEL UP line)
var _sea_t: float = 0.0           # the C9 sea clock — cosmetic, frozen under reduced motion
@onready var _field: FieldRenderer = $Field
@onready var _cam: Camera2D = $Cam
@onready var _sea: ColorRect = $SeaLayer/Sea
@onready var _gauges: HelmGauges = $HUD/Gauges
@onready var _title: TitleScreen = $HUD/Title
@onready var _tree: TechTreeScreen = $HUD/Tree
@onready var _devkit: DevKit = $HUD/DevKit

func _ready() -> void:
	sim_cfg = load("res://config/sim.tres") as SimConfig
	if sim_cfg == null:
		sim_cfg = SimConfig.new()
	field_cfg = load("res://config/field.tres") as FieldConfig
	if field_cfg == null:
		field_cfg = FieldConfig.new()
	base_cfgs = Configs.load_all()
	profile = Profile.load_profile()
	_step = 1.0 / float(sim_cfg.sim_hz)
	_cam.make_current()
	# C9: the sea shader's tables come from field.tres once; per-frame uniforms in _update_sea
	var sea_mat: ShaderMaterial = _sea.material
	sea_mat.set_shader_parameter("amp", field_cfg.sea_amp)
	sea_mat.set_shader_parameter("drift", field_cfg.sea_drift)
	sea_mat.set_shader_parameter("band_scale", field_cfg.sea_scale)
	sea_mat.set_shader_parameter("glint", field_cfg.glint_intensity)
	_title.bind(profile, base_cfgs.progress)
	_tree.bind(profile, base_cfgs.tech, base_cfgs.progress)
	_title.sortie_requested.connect(start_sortie)
	_title.tree_requested.connect(func() -> void: show_screen("tree"))
	_tree.back_requested.connect(func() -> void: show_screen("title"))
	if OS.is_debug_build():
		_devkit.bind(self)
	else:
		_devkit.queue_free()
	# a quiet world idles behind the menus (never stepped until a sortie starts)
	cfgs = Tech.apply(base_cfgs, profile.unlocked)
	world = GameWorld.new(0)
	_field.bind(world, field_cfg, cfgs)
	_gauges.bind(world, cfgs)
	show_screen("title")

func show_screen(next: String) -> void:
	state = next
	_title.visible = next == "title"
	_tree.visible = next == "tree"
	_gauges.visible = next == "game"
	_field.show_ship = next == "game"   # open sea behind the menus, no ghost hull under the title
	_field.queue_redraw()
	if next == "title":
		_title.queue_redraw()
	if next == "tree":
		_tree.queue_redraw()

func start_sortie() -> void:
	cfgs = Tech.apply(base_cfgs, profile.unlocked)   # tech derives config BEFORE the run
	if god_guns:
		_apply_god_guns()
	world = GameWorld.new(int(Time.get_ticks_usec()))
	_accum = 0.0
	_banked = false
	_gauges.lost_report = {}
	_field.bind(world, field_cfg, cfgs)
	_gauges.bind(world, cfgs)
	show_screen("game")

func _bank_run() -> void:   # the sortie's XP becomes career XP (the sim only ever wrote xp_run).
	# Projectiles keep stepping after run_over BY DESIGN (shells already flying land), and those
	# posthumous kills still add xp_run — so bank the DELTA every frame, never a one-shot snapshot,
	# and keep the lost card equal to what actually reached the profile ("XP fully kept on death").
	# start_sortie resets _banked, and the first bank re-zeroes _banked_xp, so a restart can never
	# re-bank the previous run's total.
	if _banked and world.xp_run <= _banked_xp:
		return
	if not _banked:
		_banked = true
		_banked_xp = 0
		_level_before_bank = base_cfgs.progress.level_info(profile.xp)["level"]
	profile.xp += world.xp_run - _banked_xp
	_banked_xp = world.xp_run
	profile.save()
	var after: int = base_cfgs.progress.level_info(profile.xp)["level"]
	_gauges.lost_report = { "xp": _banked_xp, "leveled_to": after if after > _level_before_bank else 0 }

func _apply_god_guns() -> void:
	for w in cfgs.weapons.catalog:
		w.dmg *= 20
		w.rate *= 2.5

func toggle_god_guns() -> void:   # DEV kit: rebuild the derived configs so the override is clean
	god_guns = not god_guns
	cfgs = Tech.apply(base_cfgs, profile.unlocked)
	if god_guns:
		_apply_god_guns()
	_field.bind(world, field_cfg, cfgs)
	_gauges.bind(world, cfgs)

func dev_max_level() -> void:     # DEV kit: enough XP for the whole tree, computed from the catalog
	var points: int = 0            # Σ node costs (63 today); 1 point per level past 1 ⇒ level = cost + 1
	for n in base_cfgs.tech.catalog:
		points += n.cost
	var xp: int = 0
	for lvl in range(1, points + 1):
		xp += base_cfgs.progress.xp_for_next(lvl)
	profile.xp = maxi(profile.xp, xp)
	profile.save()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match state:
			"title":
				if event.is_action("ui_accept"):
					start_sortie()
				elif event.physical_keycode == KEY_T:
					show_screen("tree")
			"tree":
				if event.is_action("ui_cancel"):
					show_screen("title")

func _update_sea(delta: float) -> void:   # C9: one-way render plumbing, runs in every state —
	if not field_cfg.reduced_motion:       # the water lives behind the menus too
		_sea_t += delta
	_field.sea_t = _sea_t
	var mat: ShaderMaterial = _sea.material
	mat.set_shader_parameter("sea_time", _sea_t)
	mat.set_shader_parameter("cam_pos", world.ship_pos if world != null else Vector2.ZERO)
	mat.set_shader_parameter("zoom", _cam.zoom.x)
	mat.set_shader_parameter("viewport_size", get_viewport_rect().size)
	mat.set_shader_parameter("hf_fade", SeaRender.hf_fade(_cam.zoom.x))

func _process(delta: float) -> void:
	_update_sea(delta)
	if state != "game":
		_field.queue_redraw()   # foam keeps drifting under the title/tree screens
		return
	if OS.is_debug_build() and Input.is_action_just_pressed("dev_toggle"):
		_devkit.visible = not _devkit.visible
		_devkit.queue_redraw()
	if world.run_over:
		_bank_run()   # every frame: shells still in the air keep landing, so keep banking the delta
		if Input.is_action_just_pressed("new_sortie") or Input.is_action_just_pressed("force_fire_all"):
			start_sortie()
			return
		if Input.is_action_just_pressed("open_tree"):
			show_screen("tree")
			return
	# input snapshot first, then step — held-key throttle/helm + hold-only force-fire
	world.input.thrust = Input.get_axis("helm_astern", "helm_ahead")
	world.input.rudder = Input.get_axis("helm_port", "helm_starboard")
	var all_guns: bool = Input.is_action_pressed("force_fire_all")
	world.input.force_all = all_guns
	world.input.force_large = Input.is_action_pressed("force_fire_large") and not all_guns
	world.input.force_medium = Input.is_action_pressed("force_fire_medium") and not all_guns
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
	if _devkit != null and is_instance_valid(_devkit) and _devkit.visible:
		_devkit.queue_redraw()
