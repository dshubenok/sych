extends Node

## Проверяет, можно ли физически пройти через двери и порталы.
##   godot --headless --path . res://scenes/tools/test_passages.tscn

func _ready() -> void:
	DaySystem.end_on_failed_spend = false
	await get_tree().process_frame
	await get_tree().physics_frame
	var errors: Array[String] = []
	var stream := Node3D.new()
	stream.name = "StreamedLocations"
	add_child(stream)
	LocationManager.set_stream_container(stream)
	LocationManager.set_container(self)

	await _check_location_doors(&"sychevalnya", errors)
	await _check_location_doors(&"territoriya_sharagi", errors)
	await _check_location_doors(&"sharaga", errors)
	await _check_stream(&"territoriya_sharagi", &"sharaga", errors)
	await _check_stream(&"territoriya_sharagi", &"naruzha", errors)
	await _check_stream(&"sharaga", &"territoriya_sharagi", errors)
	await _check_in_place_rooms(errors)
	await _check_doors_stay_open(errors)

	for e in errors:
		print("  [ERROR] %s" % e)
	if errors.is_empty():
		print("[test_passages] OK")
	else:
		print("[test_passages] ПРОВАЛ — ошибок: %d" % errors.size())
	get_tree().quit(errors.size())


func _check_location_doors(id: StringName, errors: Array) -> void:
	var def: LocationDef = LocationRegistry.get_def(id)
	var inst: Node = load(def.scene_path).instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_viewport().world_3d.direct_space_state
	var doors := _find_doors(inst)
	print("[passages] %s  дверей=%d" % [id, doors.size()])
	for door in doors:
		_disable_blocker(door)
	await get_tree().physics_frame
	for door in doors:
		var hit := _ray_through_door(space, door)
		var tag := "portal" if door is LocationPortal else "door"
		if hit:
			var cname := str(hit.collider.name) if hit.collider else "?"
			print("  BLOCKED %s %s → %s  at %s collider=%s" % [
				tag, door.name, door.target_location_id, hit.position, cname])
			errors.append("%s: %s '%s' перекрыт коллизией (%s)" % [id, tag, door.name, cname])
		else:
			print("  OPEN    %s %s → %s" % [tag, door.name, door.target_location_id])
		if door is StreamingDoor and not door.in_place:
			var other := LocationRegistry.get_def(door.target_location_id)
			if other and other.has_scene():
				var packed: PackedScene = load(other.scene_path)
				var other_inst: Node = packed.instantiate()
				var tmp := Node3D.new()
				add_child(tmp)
				tmp.add_child(other_inst)
				await get_tree().process_frame
				var ret := LocationManager._find_return_door(other_inst, id)
				if ret == null:
					print("  NO-RET  %s → %s (нет двери назад)" % [id, door.target_location_id])
					errors.append("%s: нет двери назад из %s" % [id, door.target_location_id])
				else:
					print("  PAIR    %s ↔ %s/%s" % [id, door.target_location_id, ret.name])
				tmp.queue_free()
				await get_tree().process_frame
	inst.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame


func _check_stream(from_id: StringName, to_id: StringName, errors: Array) -> void:
	var from_def: LocationDef = LocationRegistry.get_def(from_id)
	var from_inst: Node = load(from_def.scene_path).instantiate()
	add_child(from_inst)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var door: StreamingDoor = _find_door_to(from_inst, to_id)
	if door == null:
		errors.append("%s: нет двери в %s" % [from_id, to_id])
		from_inst.queue_free()
		await get_tree().process_frame
		return
	EnergySystem.current_energy = EnergySystem.max_energy
	door.try_open()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_viewport().world_3d.direct_space_state
	var hit := _ray_through_door(space, door)
	if hit:
		print("  STREAM-BLOCKED %s → %s  at %s collider=%s" % [
			from_id, to_id, hit.position, hit.collider.name if hit.collider else "?"])
		errors.append("после открытия %s → %s проход всё ещё закрыт" % [from_id, to_id])
	else:
		print("  STREAM-OPEN    %s → %s" % [from_id, to_id])
	LocationManager.reset_streamed()
	from_inst.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame


func _ray_through_door(space: PhysicsDirectSpaceState3D, door: Node3D) -> Dictionary:
	var xf: Transform3D = door.global_transform
	var origin: Vector3 = xf.origin + Vector3(0, 1.1, 0) - xf.basis.z * 0.8
	var dest: Vector3 = xf.origin + Vector3(0, 1.1, 0) + xf.basis.z * 0.8
	var q := PhysicsRayQueryParameters3D.create(origin, dest)
	q.collide_with_areas = false
	return space.intersect_ray(q)


func _disable_blocker(door: Node) -> void:
	var shape := door.get_node_or_null("Blocker/Shape") as CollisionShape3D
	if shape:
		shape.disabled = true


func _find_doors(node: Node, acc: Array = []) -> Array:
	for child in node.get_children():
		if child is LocationPortal or child is StreamingDoor:
			acc.append(child)
		_find_doors(child, acc)
	return acc


func _find_door_to(node: Node, target: StringName) -> StreamingDoor:
	for d in _find_doors(node):
		if d is StreamingDoor and d.target_location_id == target:
			return d
	return null


func _check_in_place_rooms(errors: Array) -> void:
	var def: LocationDef = LocationRegistry.get_def(&"sharaga")
	var inst: Node = load(def.scene_path).instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	# Проёмы в меше Шараги: по одному на крыло первого этажа, по два на крыло второго.
	var expected := [
		&"kabinet_1", &"kabinet_4",
		&"kabinet_7", &"kabinet_8", &"kabinet_9", &"kabinet_10",
	]
	EnergySystem.current_energy = 10
	var found: Array[StringName] = []
	for door in _find_doors(inst):
		if not door is StreamingDoor or not door.in_place:
			continue
		found.append(door.target_location_id)
		if not RoomPool.is_slot(door.target_location_id):
			errors.append("in-place дверь %s не слот пула" % door.target_location_id)
			continue
		var icon := door.get_node_or_null(^"EnergyIcon") as Node3D
		if icon == null or not icon.visible:
			errors.append("%s: нет значка энергии над входом" % door.target_location_id)
		var offer: Array[StringName] = RoomPool.offer_for(door.target_location_id)
		if offer.is_empty():
			print("  IN-PLACE %s (пул исчерпан)" % door.target_location_id)
			continue
		EnergySystem.current_energy = 10
		if not door.apply_choice(offer[0]):
			errors.append("%s: не открылась после выбора" % door.target_location_id)
			continue
		await get_tree().process_frame
		var drawn: StringName = RoomPool.get_drawn(door.target_location_id)
		var anchor: Node3D = door.get_node_or_null(door.sign_anchor) as Node3D
		if drawn == &"":
			print("  IN-PLACE %s (пул исчерпан)" % door.target_location_id)
		elif anchor == null or anchor.get_node_or_null(^"RoomSign") == null:
			errors.append("%s: нет 3D-вывески в комнате" % door.target_location_id)
		else:
			print("  IN-PLACE %s → %s" % [door.target_location_id, drawn])
	for id in expected:
		if not found.has(id):
			errors.append("в Шараге нет in-place двери %s" % id)
	if found.size() != expected.size():
		errors.append("ожидали %d in-place дверей, нашли %d" % [expected.size(), found.size()])
	inst.queue_free()
	await get_tree().process_frame
	LocationManager.reset_streamed()
	RoomPool._reset_day()


func _check_doors_stay_open(errors: Array) -> void:
	RoomPool._reset_day()
	EnergySystem.current_energy = 10
	var def: LocationDef = LocationRegistry.get_def(&"sharaga")
	var inst: Node = load(def.scene_path).instantiate()
	add_child(inst)
	await get_tree().process_frame
	var door: StreamingDoor = _find_door_to(inst, &"kabinet_1")
	if door == null:
		errors.append("нет двери kabinet_1 для проверки открытия")
		inst.queue_free()
		return
	var offer: Array[StringName] = RoomPool.offer_for(&"kabinet_1")
	if offer.is_empty():
		errors.append("пустой оффер kabinet_1")
		inst.queue_free()
		return
	if not door.apply_choice(offer[0]):
		errors.append("не удалось открыть kabinet_1")
		inst.queue_free()
		return
	if not door._open:
		errors.append("kabinet_1 не открылся")
	inst.queue_free()
	LocationManager.reset_streamed()
	await get_tree().process_frame
	var again: Node = load(def.scene_path).instantiate()
	add_child(again)
	await get_tree().process_frame
	await get_tree().process_frame
	var restored: StreamingDoor = _find_door_to(again, &"kabinet_1")
	if restored == null or not restored._open:
		errors.append("дверь kabinet_1 закрылась после ухода и возвращения")
	else:
		print("  OK  дверь осталась открытой после перезагрузки локации")
	again.queue_free()
	await get_tree().process_frame
	LocationManager.reset_streamed()
	RoomPool._reset_day()
