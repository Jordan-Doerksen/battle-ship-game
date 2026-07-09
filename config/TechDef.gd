class_name TechDef
extends Resource
# One node in the C4 tech tree (docs/specs/tech-tree.md). Lives as a sub-resource inside
# config/tech.tres — see TechConfig.gd. `mods` entries are { "p": "domain.field" or
# "weapons.<id>.field", and ONE of "mul" / "add" / "set" } — applied to a duplicated Configs by
# Tech.apply in catalog order. `locked` marks AIR WING nodes (visible, unbuyable, undesigned).

@export var id: String = ""
@export var branch: String = ""
@export var display_name: String = ""
@export var desc: String = ""
@export var cost: int = 1
@export var marquee: bool = false
@export var locked: bool = false
@export var mods: Array[Dictionary] = []
