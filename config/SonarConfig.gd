class_name SonarConfig
extends Resource
# C5 sonar + depth charges (docs/specs/sonar-subs.md). Instance lives at config/sonar.tres. Per the
# config-split rule this holds detection + ASW tunables ONLY; the sub itself is EnemyConfig's roster.
# The SONAR tech branch multiplies/adds onto these via mods paths "sonar.<field>" (Tech.apply).

@export var radius: float = 350.0         # passive detection radius (torpedo range is 800 — the tree closes the gap)
@export var contact_hold: float = 2.5     # seconds a contact persists after leaving the radius
@export var ripple_range: float = 260.0   # undetected-sub cosmetic tell distance (render-only read)
@export var dc_range: float = 220.0       # contact distance that arms the racks
@export var dc_count: int = 4             # charges per volley
@export var dc_ring: float = 85.0         # throw-station ring radius around the aft arc (C7 owner tune)
@export var dc_scatter: float = 90.0      # jitter around each throw station
@export var dc_fuse: float = 1.5          # sink time before detonation
@export var dc_blast: float = 55.0        # underwater blast radius
@export var dc_dmg: int = 3               # damage per blast (hp-6 sub ≈ two good volleys)
@export var dc_cooldown: float = 4.0      # seconds between volleys
