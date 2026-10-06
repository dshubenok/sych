extends Node

## Проверка целостности системы локаций. Запускается как сцена, чтобы были
## доступны автозагрузки (LocationRegistry и др.):
##   godot --headless --path . res://scenes/tools/validate_locations.tscn
##
## Проверяет: существование файлов сцен, корректность родителей, существование
## целей порталов (включая exit_ids placeholder-локаций), наличие точки спавна,
## совпадение location_id сцены с реестром. Завершает процесс кодом = числу ошибок.

func _ready() -> void:
	await get_tree().process_frame
	var errors: Array[String] = []
	var warnings: Array[String] = []

	var ids = LocationRegistry.all_ids()
	print("[validate] локаций в реестре: %d" % ids.size())

	for id in ids:
		var def: LocationDef = LocationRegistry.get_def(id)
		if def.parent_id != &"" and not LocationRegistry.has(def.parent_id):
			errors.append("%s: родитель '%s' не найден" % [id, def.parent_id])
		if def.has_scene():
			if not ResourceLoader.exists(def.scene_path):
				errors.append("%s: сцена не найдена: %s" % [id, def.scene_path])
			else:
				await _check_scene(def, errors, warnings)
		elif def.type == LocationTypes.Type.ROOT:
			pass
		elif RoomPool.is_slot(id) or def.type == LocationTypes.Type.FLOOR:
			print("  OK  %s  →  %s" % [id, LocationRegistry.breadcrumb_text(id)])
		else:
			warnings.append("%s: нет сцены (тип не ROOT)" % id)

	_report(errors, warnings)
	get_tree().quit(errors.size())

func _check_scene(def: LocationDef, errors: Array, warnings: Array) -> void:
	var packed: PackedScene = load(def.scene_path)
	if packed == null:
		errors.append("%s: не удалось загрузить сцену" % def.id)
		return
	var inst = packed.instantiate()
	if inst == null:
		errors.append("%s: сцена не инстанцируется" % def.id)
		return
	add_child(inst)
	await get_tree().process_frame

	var scene_id: StringName = inst.get("location_id")
	if scene_id != def.id:
		warnings.append("%s: location_id в сцене = '%s'" % [def.id, scene_id])

	if inst.get_node_or_null(^"PlayerSpawn") == null:
		var eps = inst.get("entry_points")
		if eps == null or (eps as Array).is_empty():
			warnings.append("%s: нет PlayerSpawn / entry_points" % def.id)

	# Соседи placeholder-локаций (двери-стримеры и порталы).
	for prop in ["stream_exits", "portal_exits"]:
		var arr = inst.get(prop)
		if arr != null:
			for target in (arr as Array):
				if not LocationRegistry.has(target):
					errors.append("%s: %s ведёт в несуществующую '%s'" % [def.id, prop, target])

	# Явные узлы-двери (порталы и стримеры, например в Сычевальне).
	for door in _find_doors(inst):
		var target: StringName = door.target_location_id
		if target == &"":
			errors.append("%s: дверь '%s' без цели" % [def.id, door.name])
		elif not LocationRegistry.has(target):
			errors.append("%s: дверь ведёт в несуществующую '%s'" % [def.id, target])

	print("  OK  %s  →  %s" % [def.id, LocationRegistry.breadcrumb_text(def.id)])
	inst.queue_free()
	await get_tree().process_frame

func _find_doors(node: Node, acc: Array = []) -> Array:
	for child in node.get_children():
		if child is LocationPortal or child is StreamingDoor:
			acc.append(child)
		_find_doors(child, acc)
	return acc

func _report(errors: Array, warnings: Array) -> void:
	for w in warnings:
		print("  [warn] %s" % w)
	for e in errors:
		print("  [ERROR] %s" % e)
	if errors.is_empty():
		print("[validate] OK — ошибок нет (предупреждений: %d)" % warnings.size())
	else:
		print("[validate] ПРОВАЛ — ошибок: %d" % errors.size())
