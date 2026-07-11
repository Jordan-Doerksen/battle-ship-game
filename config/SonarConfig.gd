class_name SonarConfig
extends Resource
# C5 sonar + depth charges (docs/specs/sonar-subs.md). Instance lives at config/sonar.tres. Per the
# config-split rule this holds detection + ASW tunables ONLY; the sub itself is EnemyConfig's roster.
# The SONAR tech branch multiplies/adds onto these via mods paths "sonar.<field>" (Tech.apply).

# DC REWORK 2026-07-10 (owner: the racks were too hard to land). Two levers: find/reach subs sooner
# (radius + dc_range + contact_hold up) and — the feel fix — the plot now RANGES the pattern onto the
# detected contact instead of blanketing the stern blind (DepthCharges.gd). Still scattered area
# denial, just centered where the contact is. Supersedes the C7 blind K-gun aft-arc tune.
@export var radius: float = 440.0         # passive detection radius (was 350; closes the torpedo-range gap)
@export var contact_hold: float = 3.5     # seconds a contact persists after leaving the radius (was 2.5)
@export var ripple_range: float = 260.0   # undetected-sub cosmetic tell distance (render-only read)
@export var dc_range: float = 260.0       # contact distance that arms the racks AND the pattern's max reach
@export var dc_count: int = 4             # charges per volley
@export var dc_ring: float = 97.0         # MINIMUM throw distance — a close contact still lands clear of the hull
@export var dc_scatter: float = 75.0      # jitter around the aim point (was 90; the centering does the rest)
@export var dc_fuse: float = 1.5          # sink time before detonation
@export var dc_blast: float = 55.0        # underwater blast radius
@export var dc_dmg: int = 3               # damage per blast (hp-6 sub ≈ two good volleys)
@export var dc_cooldown: float = 4.0      # seconds between volleys
