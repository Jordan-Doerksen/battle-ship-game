class_name FieldRenderer
extends Node2D
# Draws the world in WORLD coordinates; the Camera2D centers on `world.ship_pos` (Main sets this each
# frame). Reads the world, writes nothing back (one-way sim → render). C2 look is LOOK-LOCKED
# (battleship hull ×2.4, class-distinct turret art ON the hull per D1.5, recoil); C3 adds the war;
# C9 teaches the water to move (design/living-sea.html, direction B "HEAVY WEATHER" approved
# 2026-07-09) — the sea shader lives on Main's SeaLayer, everything else routes through the
# render-domain helpers (SeaRender / ShipRender / HostileRender / FxRender; split per the house
# 500-line rule at C9). Effects arrive via consume_effects() — Main plumbs the sim's event batch
# here after stepping; this node never touches world.effects itself.

const SEA := Color(0.039, 0.118, 0.157)      # #0A1E28
const FOAM := Color(0.894, 0.941, 0.949)     # #E4F0F2
const HULL := Color(0.235, 0.310, 0.341)     # #3C4F57
const DECK := Color(0.353, 0.439, 0.478)     # #5A707A
const STEEL := Color(0.576, 0.655, 0.682)    # #93A7AE
const HOUSE := Color(0.392, 0.471, 0.522)    # #647885 — turret houses
const HOUSE_FORCED := Color(0.431, 0.353, 0.314)  # #6E5A50 — force-fired tint
const FLASH := Color(0.910, 0.706, 0.431)    # muzzle
const RED := Color(0.851, 0.310, 0.169)      # #D94F2B
const HULL_SCALE := 2.75   # C14: ~15% up from the C2 gate's 2.4 — deck room (owner directive)
const FLASH_LEN := { "L": 35.0, "M": 22.0, "S": 13.0 }
const SUN_DIR := Vector2(-0.55, -0.835)      # light from upper-left…
const SHADOW_DIR := Vector2(0.55, 0.835)     # …shadows fall lower-right (matches the C6/C7 shadows)

# one-shot fx lifetimes (splash/gunsplash route to the C9 column system instead of this table;
# klaxon/waveclear stay 0.0 — emitted-and-dropped until the C12 SFX pass gives them a voice)
const FX_LIFE := {
	"muzzle": 0.12, "gunflash": 0.12, "hit": 0.12, "ignite": 0.3, "shiphit": 0.4,
	"airburst": 0.45, "death": 0.5, "crashturn": 0.8, "shipdeath": 2.2,
	"dcvolley": 0.3, "dcblast": 0.9, "contact": 1.2,
	"rockhit": 0.4, "grind": 0.25,   # C15: fire dying on rock · hull scraping the coast
	"helodrop": 0.35, "helodown": 0.5,
	"partdown": 0.6, "bossdown": 2.0, "breach": 1.0, "dive": 0.8,
	"klaxon": 0.0, "waveclear": 0.0,
	"capsize": 1.4, "wx": 0.0,   # C18: the grinder's spin-under · C17: front edges (sfx/plate only)
}

var _world: GameWorld
var _field_cfg: FieldConfig
var _cam_cfg: CameraConfig
var _cfgs: Configs
var _flecks: Array = []
var _wake: Array = []
var _fx: Array = []                          # render-side animated effects
var _splashes: Array = []                    # C9 splash columns (FxRender)
var _streaks: Array = []                     # C9 crest-foam streaks (SeaRender)
var _terrain_art: Array = []                 # C15 cached terrain cosmetics (TerrainRender builds)
var _recoil: Array = []                      # per-mount barrel kick, fed by muzzle effects
var _srng := RandomNumberGenerator.new()     # cosmetic-only randomness — never world.rng (D1.4)
var _last_emit: float = -1.0
var _hull_outline: PackedVector2Array
var _death_ms: int = -1                      # when the shipdeath effect landed (wreck fade timer)
var show_ship: bool = true                   # Main clears it behind the title/tree screens (C4)
var sea_t: float = 0.0                       # the render sea clock — Main pushes it (frozen under
                                             # reduced motion; never the sim clock, cosmetics only)
var radio_signal_t: float = -100.0           # FLEET RADIO: sea_t when the last comms line arrived —
                                             # Main stamps it on RadioComms.consume_signal(); the dish
                                             # pulses off (sea_t − this). -100 = "long ago" (no ring)
var target_zoom: float = 0.51                # C10: Main pushes the wheel TARGET — fades key off it
var _wx: Dictionary = {}                     # C17 weather-render state (drops/dimples/bolts/flash) —
                                             # WeatherRender owns it; lazily built, cosmetic rng only
var _amb: Dictionary = {}                    # C19 detail-pass state (slicks/haze/gulls/…) —
                                             # AmbienceRender owns it; same rules

func bind(world: GameWorld, field_cfg: FieldConfig, cam_cfg: CameraConfig, cfgs: Configs) -> void:
	_world = world
	_field_cfg = field_cfg
	_cam_cfg = cam_cfg
	_cfgs = cfgs
	_build_flecks()
	_hull_outline = ShipRender.build_hull_outline()
	_recoil.resize(cfgs.hardpoints.mount_pos.size())
	_recoil.fill(0.0)
	_srng.seed = world.world_seed ^ 0x0C9A11FE
	_fx.clear()
	_splashes.clear()
	_streaks.clear()
	_terrain_art.clear()   # C15: rebuilt lazily off the new world's terrain + seed
	_wake.clear()
	_last_emit = -1.0
	_death_ms = -1

# Main hands over the sim's effect batch each frame (one-way; see GameWorld.effects)
func consume_effects(events: Array) -> void:
	var now: int = Time.get_ticks_msec()
	for e in events:
		AmbienceRender.on_event(self, e, now)   # C19: slicks/haze/casings/gull-scatter (non-consuming)
		if e["type"] == "muzzle" and e["idx"] < _recoil.size():
			_recoil[e["idx"]] = 1.0
		if e["type"] == "shipdeath":
			_death_ms = now
		if e["type"] == "splash" or e["type"] == "gunsplash":
			FxRender.spawn_splash(self, e, now)   # C9: water columns, not rings
			continue
		var fxe: Dictionary = e.duplicate()
		fxe["t0"] = now
		_fx.append(fxe)

func _build_flecks() -> void:
	var srng := RandomNumberGenerator.new()   # seeded per world, stable fleck field
	srng.seed = _world.world_seed ^ 0x51ED2317
	_flecks.clear()
	for i in range(_field_cfg.fleck_count):
		_flecks.append({
			"x": srng.randf() * _field_cfg.field_tile,
			"y": srng.randf() * _field_cfg.field_tile,
			"len": _field_cfg.fleck_min_len + srng.randf() * (_field_cfg.fleck_max_len - _field_cfg.fleck_min_len),
			"ph": srng.randf() * TAU,
		})

func _process(_delta: float) -> void:
	if _world == null:
		return
	if _world.elapsed - _last_emit >= 1.0 / 60.0:
		_last_emit = _world.elapsed
		SeaRender.emit_wake(self)
	while _wake.size() > 0 and _world.elapsed - _wake[0]["t"] >= _field_cfg.wake_life:
		_wake.pop_front()
	SeaRender.step_streaks(self)

func _draw() -> void:
	if _world == null:
		return
	SeaRender.draw_grid(self)
	AmbienceRender.draw_clouds(self)   # C19: cloud shadows on the water, under everything alive
	SeaRender.draw_flecks(self)
	SeaRender.draw_streaks(self)
	SeaRender.draw_wake(self)
	TerrainRender.draw(self)   # C15: the waters are world furniture — land stays visible behind
	                           # the menus/attract like the sea does, so it sits above the wake
	                           # but BEFORE the show_ship gate
	WhirlpoolRender.draw(self) # C18: the vortex is water furniture too — under everything that floats
	AmbienceRender.draw_water(self)   # C19: slicks/boils/flotsam/buoys — the strait is a place
	if not show_ship:   # open sea only behind the menus (C4/C8): no dead-run combat layers
		return
	FxRender.draw_splash_water(self)          # discs + column shadows — water level, under hulls
	HostileRender.draw_enemies(self)
	HostileRender.draw_boss(self)
	FxRender.draw_projectiles(self)
	var rd: Dictionary = ShipRender.ride(self)
	ShipRender.draw_hull(self, rd)
	ShipRender.draw_mounts(self, rd)
	ShipRender.draw_helo(self)
	AmbienceRender.draw_ship_fx(self)         # C19: smoke/casings/sprays/lamp/gulls — the crewed read
	FxRender.draw_splash_plumes(self)         # the columns occlude what they land on
	FxRender.draw_fx(self)
	WeatherRender.draw(self)                  # C17: rain/veil/lightning — over everything (the sky)

func view_rect() -> Rect2:
	# culls around the CAMERA, not the ship — identical in a sortie (the cam is ship-locked),
	# but the C12 attract camera rides off-center and ship-centered culling would pop the edges
	var cam := get_viewport().get_camera_2d()
	var size: Vector2 = get_viewport_rect().size / (cam.zoom if cam != null else Vector2.ONE)
	return Rect2((cam.position if cam != null else _world.ship_pos) - size * 0.5, size)

func zoom() -> float:
	var cam := get_viewport().get_camera_2d()
	return cam.zoom.x if cam != null else 1.0

# C10 stroke compensation: world-art outline widths hold their 0.85-baseline apparent weight
# under zoom-out (identical to the LOOK-LOCKED view at 0.85; capped so nothing turns to rope).
func lw(w: float) -> float:
	if _cam_cfg == null or not _cam_cfg.stroke_comp:
		return w
	return w * clampf(0.85 / zoom(), 1.0, 2.2)

# C10 minimum-apparent-size floor: the smallest hostiles never render under enemy_min_px.
func size_floor(world_len: float) -> float:
	if _cam_cfg == null:
		return 1.0
	return maxf(1.0, _cam_cfg.enemy_min_px / maxf(world_len * zoom(), 0.001))

func wreck_alpha() -> float:
	if not _world.run_over or _death_ms < 0:
		return 1.0
	return clampf(1.0 - (Time.get_ticks_msec() - _death_ms) / 1400.0, 0.0, 1.0)   # the wreck slips under

func wreck_fade(c: Color, fade: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * fade)
