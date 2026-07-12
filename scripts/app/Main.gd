extends Node2D
# Root (app domain). Owns the fixed-step accumulator, the C4 state machine (title / tree / game /
# manual — the C13 FIELD MANUAL),
# the persistent Profile (banked at run end; the sim never reads it), and the InputState snapshot —
# still the ONLY door input enters the sim through. Each sortie derives its Configs from the base
# .tres values + the profile's unlocked tech (Tech.apply) BEFORE the world is created, so
# determinism per (seed, unlock set) holds. The DEV test kit exists only in debug builds.
# C12 (docs/specs/readability-feel.md): pause (the war waits, the sea doesn't), the key-only lost
# card, and the SfxPlayer fed off the same one-way effect batch. The FLEET RADIO (RadioComms) now
# owns the contextual-drip teaching — absorbed into TF50 ACTUAL's narrative comms feed.

const LOST_HOLD_MS := 1500   # C12 lost-card guard: the card holds this long before R/T answer

var radio: RadioComms = RadioComms.new()   # the FLEET RADIO message engine (app layer; one-way reads)
var world: GameWorld
var sim_cfg: SimConfig
var field_cfg: FieldConfig
var cam_cfg: CameraConfig
var audio_cfg: AudioConfig
var base_cfgs: Configs
var cfgs: Configs
var profile: Profile
var paused: bool = false          # C12: P toggles mid-sortie; sim/input/effects hold, render runs
var god_guns: bool = false        # DEV kit weapon override, rebuilt into cfgs per toggle/sortie
var state: String = "title"       # title | tree | game | manual
var _accum: float = 0.0
var _step: float = 1.0 / 60.0
var _banked: bool = false
var _banked_xp: int = 0           # this run's XP already in the profile (posthumous kills bank the delta)
var _level_before_bank: int = 1   # career level when this run's banking began (for the LEVEL UP line)
var _sea_t: float = 0.0           # the C9 sea clock — cosmetic, frozen under reduced motion
var _target_zoom: float = 0.51    # C10: the wheel drives this; the camera lerps toward it
var _lost_ms: int = -1            # C12: tick when run_over was first observed (-1 = alive)
var _attract_wait: float = 0.0    # C12 attract: seconds since the demo ship died (relaunch timer)
@onready var _field: FieldRenderer = $Field
@onready var _cam: Camera2D = $Cam
@onready var _sea: ColorRect = $SeaLayer/Sea
@onready var _gauges: HelmGauges = $HUD/Gauges
@onready var _title: TitleScreen = $HUD/Title
@onready var _tree: TechTreeScreen = $HUD/Tree
@onready var _manual: TutorialScreen = $HUD/Manual
@onready var _devkit: DevKit = $HUD/DevKit
@onready var _sfx: SfxPlayer = $Sfx

func _ready() -> void:
	sim_cfg = load("res://config/sim.tres") as SimConfig
	if sim_cfg == null:
		sim_cfg = SimConfig.new()
	field_cfg = load("res://config/field.tres") as FieldConfig
	if field_cfg == null:
		field_cfg = FieldConfig.new()
	cam_cfg = load("res://config/camera.tres") as CameraConfig
	if cam_cfg == null:
		cam_cfg = CameraConfig.new()
	audio_cfg = load("res://config/audio.tres") as AudioConfig
	if audio_cfg == null:
		audio_cfg = AudioConfig.new()
	_sfx.bind(audio_cfg)
	_target_zoom = cam_cfg.zoom_home
	_cam.zoom = Vector2.ONE * _target_zoom   # C10: the .tscn hardcode died; config rules the camera
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
	_manual.bind(field_cfg)   # the manual only needs reduced_motion; fonts are self-made
	_title.sortie_requested.connect(start_sortie)
	_title.tree_requested.connect(func() -> void: show_screen("tree"))
	_title.manual_requested.connect(_open_manual)
	_tree.back_requested.connect(func() -> void: show_screen("title"))
	if OS.is_debug_build():
		_devkit.bind(self)
	else:
		_devkit.queue_free()
	# C12 play-test tune: the title needed some action — an auto-piloted ATTRACT sortie runs
	# behind the menus (real sim, synthetic helm, the player's own unlocks; nothing banks)
	_start_attract()
	show_screen("title")

func show_screen(next: String) -> void:
	state = next
	_title.visible = next == "title"
	_tree.visible = next == "tree"
	_manual.visible = next == "manual"
	_gauges.visible = next == "game"
	# the attract war shows under the title; the tree and manual keep open sea (C13)
	_field.show_ship = next == "game" or next == "title"
	_field.queue_redraw()
	if next == "title":
		_title.queue_redraw()
	if next == "tree":
		_tree.queue_redraw()
	if next == "manual":
		_manual.queue_redraw()

func _open_manual() -> void:   # title button + M share this door; the manual opens at page one
	_manual.open()
	show_screen("manual")

# C12 attract, cranked at the play-test (owner: "tons of shit on screen, max ALL upgrades,
# invulnerable — JUST for the title"): the demo ship owns the whole tree, can't die, and the
# director fields a crowded ocean with machines every 3rd wave. Real sim, synthetic helm;
# never banked, never hinted — start_sortie re-derives honest configs from the profile.
func _start_attract() -> void:
	var all_ids: Array = []
	for n in base_cfgs.tech.catalog:
		all_ids.append(n.id)
	cfgs = Tech.apply(base_cfgs, all_ids)
	cfgs.waves.first_wave_delay = 1.5
	cfgs.waves.base_budget = 30
	cfgs.waves.budget_per_wave = 14
	cfgs.waves.quiet_secs = 2.0         # C16: the demo doesn't breathe — the player isn't in it (the real quiet)
	cfgs.waves.spawn_ring_min = 900.0   # arrivals land in frame instead of a horizon away
	cfgs.waves.spawn_ring_max = 1300.0
	cfgs.waves.cluster_min = 3          # every bearing at once — the crowded ocean
	cfgs.bosses.every_n = 2
	world = GameWorld.new(int(Time.get_ticks_usec()))
	Terrain.generate(world, cfgs)   # C15: the demo fights in real waters too (first rng draws, stable)
	Weather.generate(world, cfgs)   # C17: the attract weathers the same fronts (substream, zero rng draws)
	world.godmode = true
	_accum = 0.0
	_attract_wait = 0.0
	_field.bind(world, field_cfg, cam_cfg, cfgs)
	_gauges.bind(world, cfgs)

func _step_attract(delta: float) -> void:
	if world.elapsed > 90.0:   # the invulnerable demo never dies — relaunch before the war
		_start_attract()        # escalates past what an idle menu should be simulating
		return
	if world.run_over:
		_attract_wait += delta   # (unreachable under godmode; kept for safety)
		if _attract_wait > 3.0:
			_start_attract()
			return
	else:
		world.input.thrust = 1.0 if Movement.keel_speeds(world).x < cfgs.movement.max_speed_ahead * 0.75 else 0.0
		world.input.rudder = sin(world.elapsed * 0.07) * 0.35 + sin(world.elapsed * 0.023 + 1.7) * 0.2
		world.input.force_all = false
		world.input.force_large = false
		world.input.force_medium = false
	_accum += delta
	var steps: int = 0
	while _accum >= _step and steps < sim_cfg.max_frame_catchup:
		Sim.step(world, _step, cfgs)
		_accum -= _step
		steps += 1
	if steps >= sim_cfg.max_frame_catchup:
		_accum = 0.0
	_field.consume_effects(world.effects)
	_sfx.consume_effects(world.effects, world.elapsed)
	world.effects.clear()
	# off-center follow: the title plate owns screen center — the demo ship rides beside it
	_cam.position = world.ship_pos - Vector2(700.0, 250.0)

func start_sortie() -> void:
	cfgs = Tech.apply(base_cfgs, profile.unlocked)   # tech derives config BEFORE the run
	if god_guns:
		_apply_god_guns()
	world = GameWorld.new(int(Time.get_ticks_usec()))
	Terrain.generate(world, cfgs)   # C15: same seed = same archipelago (the world's first rng draws)
	Weather.generate(world, cfgs)   # C17: same seed = same fronts (dedicated substream, zero rng draws)
	_accum = 0.0
	_banked = false
	paused = false
	_lost_ms = -1
	radio.reset()                      # fresh comms net for the new picket (FLEET RADIO)
	_target_zoom = cam_cfg.zoom_home   # sorties start at the home view (C10 gate)
	_gauges.lost_report = {}
	_field.bind(world, field_cfg, cam_cfg, cfgs)
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
	_field.bind(world, field_cfg, cam_cfg, cfgs)
	_gauges.bind(world, cfgs)

func dev_max_level() -> void:     # DEV kit: enough XP for the whole tree, computed from the catalog
	var points: int = 0            # Σ node costs (65 today); 1 point per level past 1 ⇒ level = cost + 1
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
				elif event.physical_keycode == KEY_M:
					_open_manual()
			"tree":
				if event.is_action("ui_cancel"):
					show_screen("title")
			"manual":
				if event.is_action("ui_cancel") or event.physical_keycode == KEY_M:
					show_screen("title")
				elif event.physical_keycode == KEY_LEFT or event.physical_keycode == KEY_A:
					_manual.flip(-1)
				elif event.physical_keycode == KEY_RIGHT or event.physical_keycode == KEY_D:
					_manual.flip(1)

func _update_sea(delta: float) -> void:   # C9: one-way render plumbing, runs in every state —
	if not field_cfg.reduced_motion:       # the water lives behind the menus too
		_sea_t += delta
	_field.sea_t = _sea_t
	_field.target_zoom = _target_zoom      # C10: fades key off the TARGET so nothing shimmers mid-lerp
	var mat: ShaderMaterial = _sea.material
	mat.set_shader_parameter("sea_time", _sea_t)
	mat.set_shader_parameter("cam_pos", world.ship_pos if world != null else Vector2.ZERO)
	mat.set_shader_parameter("zoom", _cam.zoom.x)
	mat.set_shader_parameter("viewport_size", get_viewport_rect().size)
	mat.set_shader_parameter("hf_fade", SeaRender.hf_fade(_target_zoom))

func _update_camera(delta: float) -> void:   # C10 tactical zoom — app/render only, sim-blind
	if state == "game":
		if Input.is_action_just_pressed("zoom_in"):
			_target_zoom = clampf(_target_zoom * cam_cfg.wheel_step, cam_cfg.zoom_min, cam_cfg.zoom_max)
		if Input.is_action_just_pressed("zoom_out"):
			_target_zoom = clampf(_target_zoom / cam_cfg.wheel_step, cam_cfg.zoom_min, cam_cfg.zoom_max)
		if Input.is_action_just_pressed("zoom_home"):
			_target_zoom = clampf(cam_cfg.zoom_home, cam_cfg.zoom_min, cam_cfg.zoom_max)
	var k: float = 1.0 - pow(0.5, delta / maxf(cam_cfg.lerp_half_life, 0.001))
	_cam.zoom = _cam.zoom.lerp(Vector2.ONE * _target_zoom, k)

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_sea(delta)
	if state != "game":
		if state == "title":
			_step_attract(delta)   # C12: the attract war fights on under the title
		_field.queue_redraw()      # foam keeps drifting under the title/tree screens
		return
	if OS.is_debug_build() and Input.is_action_just_pressed("dev_toggle"):
		_devkit.visible = not _devkit.visible
		_devkit.queue_redraw()
	if Input.is_action_just_pressed("pause") and not world.run_over:   # C12: the war waits…
		paused = not paused
	_gauges.paused = paused
	if world.run_over:
		_bank_run()   # every frame: shells still in the air keep landing, so keep banking the delta
		if _lost_ms < 0:
			_lost_ms = Time.get_ticks_msec()   # C12 lost-card guard starts its hold
		if Time.get_ticks_msec() - _lost_ms >= LOST_HOLD_MS:   # key-only restart, never the combat button
			if Input.is_action_just_pressed("new_sortie"):
				start_sortie()
				return
			if Input.is_action_just_pressed("open_tree"):
				show_screen("tree")
				return
	if not paused:   # C12: …but the sea below keeps drifting (camera/sea/redraws run either way)
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
		_gauges.consume_effects(world.effects)  # the scope takes the same batch (C11 fall-of-shot),
		_sfx.consume_effects(world.effects, world.elapsed)   # C12: the same batch, now audible
		_sfx.set_weather(world.wx_state)        # C17: the rain bed + thunder ride the state (self-stopping watchdog)
		world.effects.clear()                   # and the app layer clears — render never touches the world
		if not world.run_over:                  # FLEET RADIO: evaluate comms triggers (one-way reads),
			radio.tick(world, cfgs, profile, self)   # then chime + pulse the dish on a fresh line
			if radio.consume_signal():
				_field.radio_signal_t = _sea_t
				_sfx.play_ui("radio")
	_gauges.radio_lines = radio.display_lines()   # the panel keeps typing even while paused (render clock)
	_cam.position = world.ship_pos
	_field.queue_redraw()
	_gauges.queue_redraw()
	if _devkit != null and is_instance_valid(_devkit) and _devkit.visible:
		_devkit.queue_redraw()
