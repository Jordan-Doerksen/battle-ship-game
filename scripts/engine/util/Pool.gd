class_name Pool
extends RefCounted
# Object pool — no per-frame allocation in hot paths. O(1) obtain/release via a free stack. Pooled
# objects must expose `_idx`, `active`, and `uid` fields. `uid` is the stable identity for a lifetime;
# `_idx` is only a slot — never use it as identity. Not yet consumed anywhere (no entity pools exist
# until C1 lands enemies/projectiles) — kept here as the shared primitive future systems will use.

var factory: Callable
var items: Array = []
var free: Array[int] = []
var count: int = 0
var _uid: int = 0

func _init(factory_: Callable) -> void:
	factory = factory_

func obtain() -> Variant:
	var obj: Variant
	if free.size() > 0:
		obj = items[free.pop_back()]
	else:
		obj = factory.call()
		obj._idx = items.size()
		items.append(obj)
	obj.active = true
	_uid += 1
	obj.uid = _uid
	count += 1
	return obj

func release(obj: Variant) -> void:
	if not obj.active:
		return
	obj.active = false
	free.push_back(obj._idx)
	count -= 1

func clear() -> void:
	free.clear()
	for i in range(items.size() - 1, -1, -1):
		items[i].active = false
		free.push_back(i)
	count = 0
