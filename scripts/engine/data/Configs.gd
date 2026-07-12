class_name Configs
extends RefCounted
# The bundle of per-system config handles that Sim.step threads to its systems. Each domain STILL
# lives in its own small .tres (the config-split rule in config/SimConfig.gd) — this class is only
# the carrier, so Sim.step's signature doesn't grow a parameter per chunk. `gunnery` is the practice
# range (RangeConfig); named to avoid shadowing GDScript's range().

var movement: MovementConfig
var hardpoints: HardpointConfig
var weapons: WeaponConfig
var waves: WaveConfig
var enemies: EnemyConfig
var progress: ProgressConfig
var tech: TechConfig
var sonar: SonarConfig
var airwing: AirWingConfig
var bosses: BossConfig
var terrain: TerrainConfig
var weather: WeatherConfig
var whirlpool: WhirlpoolConfig

# Class-default values (which mirror every .tres) — probes use this so they run without the
# resource files; Main uses load_all() for the real tunables.
static func defaults() -> Configs:
	var c := Configs.new()
	c.movement = MovementConfig.new()
	c.hardpoints = HardpointConfig.new()
	c.weapons = WeaponConfig.spec_defaults()
	c.waves = WaveConfig.new()
	c.enemies = EnemyConfig.spec_defaults()
	c.progress = ProgressConfig.new()
	c.tech = TechConfig.spec_defaults()
	c.sonar = SonarConfig.new()
	c.airwing = AirWingConfig.new()
	c.bosses = BossConfig.spec_defaults()
	c.terrain = TerrainConfig.new()
	c.weather = WeatherConfig.new()
	c.whirlpool = WhirlpoolConfig.new()
	return c

static func load_all() -> Configs:
	var c := defaults()
	var m := load("res://config/movement.tres") as MovementConfig
	if m != null: c.movement = m
	var h := load("res://config/hardpoint.tres") as HardpointConfig
	if h != null: c.hardpoints = h
	var w := load("res://config/weapons.tres") as WeaponConfig
	if w != null and w.catalog.size() > 0: c.weapons = w
	var wv := load("res://config/waves.tres") as WaveConfig
	if wv != null: c.waves = wv
	var en := load("res://config/enemies.tres") as EnemyConfig
	if en != null and en.roster.size() > 0: c.enemies = en
	var pr := load("res://config/progress.tres") as ProgressConfig
	if pr != null: c.progress = pr
	var te := load("res://config/tech.tres") as TechConfig
	if te != null and te.catalog.size() > 0: c.tech = te
	var so := load("res://config/sonar.tres") as SonarConfig
	if so != null: c.sonar = so
	var aw := load("res://config/airwing.tres") as AirWingConfig
	if aw != null: c.airwing = aw
	var bo := load("res://config/bosses.tres") as BossConfig
	if bo != null and bo.defs.size() > 0: c.bosses = bo
	var tr := load("res://config/terrain.tres") as TerrainConfig
	if tr != null: c.terrain = tr
	var wx := load("res://config/weather.tres") as WeatherConfig
	if wx != null: c.weather = wx
	var wp := load("res://config/whirlpool.tres") as WhirlpoolConfig
	if wp != null: c.whirlpool = wp
	return c
