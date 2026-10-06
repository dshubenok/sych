extends Node

## Менеджер локаций (автозагрузка): загрузка/выгрузка сцен, переходы между
## локациями и перенос Сыча. Работает в паре с LocationRegistry.
##
## Сыч, камера, HUD и глобальные системы остаются персистентными в корневой
## сцене; меняется только содержимое контейнера текущей локации.

signal location_exiting(location_id: StringName)
signal location_entered(location_id: StringName)

const FADE_LAYER := 200
const FADE_TIME := 0.45
const HOME := &"sychevalnya"

var current_location_id: StringName = &""
var current_location: Node = null

var _container: Node = null
var _busy := false
var _fade_layer: CanvasLayer = null
var _fade_rect: ColorRect = null

# --- Бесшовный стриминг внутри Территории ---
var _streamed: Dictionary = {}        # StringName -> Node
var _stream_container: Node = null
var _breadcrumb_location_id: StringName = &""
var _in_place_open: Dictionary = {}   # StringName slot -> true
## Двери, открытые в этот день. Живут через уход домой, сброс — в конце дня.
var _opened_today: Dictionary = {}    # StringName location/slot -> true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Сброс застримленного и возврат домой в конце дня.
	DaySystem.day_ended.connect(_on_day_ended)

## Куда добавлять загруженные сцены локаций. Вызывается из корневой сцены.
func set_container(node: Node) -> void:
	_container = node

func _resolve_container() -> Node:
	if is_instance_valid(_container):
		return _container
	_container = get_tree().get_first_node_in_group(&"location_container")
	return _container

## Стартовая локация при запуске игры: без затемнения-выхода, сразу проявляем.
func start_at(location_id: StringName, entry_name: StringName = &"") -> void:
	if _busy:
		return
	var def := LocationRegistry.get_def(location_id)
	if def == null or not def.has_scene():
		push_error("[LocationManager] Стартовая локация недоступна: %s" % location_id)
		return
	_busy = true
	_ensure_fade()
	_set_fade(1.0)
	var ok := await _swap_to(def, location_id, entry_name)
	if ok:
		location_entered.emit(location_id)
	await _fade(0.0)
	_busy = false

## Переход в другую локацию (используется порталами).
func travel_to(location_id: StringName, entry_name: StringName = &"") -> void:
	if _busy:
		return
	if location_id == current_location_id:
		return
	var def := LocationRegistry.get_def(location_id)
	if def == null:
		push_error("[LocationManager] Неизвестная локация: %s" % location_id)
		return
	if not def.has_scene():
		push_error("[LocationManager] У локации нет сцены: %s" % location_id)
		return
	_busy = true
	_ensure_fade()
	await _fade(1.0)
	if current_location_id != &"":
		location_exiting.emit(current_location_id)
	var ok := await _swap_to(def, location_id, entry_name)
	if ok:
		location_entered.emit(location_id)
	await _fade(0.0)
	_busy = false

# --- Внутреннее ----------------------------------------------------------

func _swap_to(def: LocationDef, location_id: StringName, entry_name: StringName) -> bool:
	# Смена дискретной зоны сбрасывает всё, что было застримлено в прошлой.
	reset_streamed()
	_unload_current()
	var scene := await _load_scene(def.scene_path)
	if scene == null:
		return false
	var container := _resolve_container()
	if container == null:
		push_error("[LocationManager] Не найден контейнер локаций.")
		scene.queue_free()
		return false
	container.add_child(scene)
	current_location = scene
	current_location_id = location_id
	_breadcrumb_location_id = location_id
	CabinetPool.apply(scene)
	# _ready сцены уже отработал (SychSpawn создан) — ставим Сыча.
	_place_sych(scene, entry_name)
	return true

func _unload_current() -> void:
	if is_instance_valid(current_location):
		current_location.queue_free()
	current_location = null
	current_location_id = &""

func _load_scene(path: String) -> Node:
	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		push_error("[LocationManager] Не удалось начать загрузку: %s" % path)
		return null
	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED \
				or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("[LocationManager] Ошибка загрузки сцены: %s" % path)
			return null
		await get_tree().process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(path)
	if packed == null:
		return null
	return packed.instantiate()

func _place_sych(location: Node, entry_name: StringName) -> void:
	var sych := get_tree().get_first_node_in_group(&"sych")
	if sych == null or not sych is Node3D:
		return
	var entry: Node3D = null
	if location.has_method("get_entry_point"):
		entry = location.get_entry_point(entry_name)
	if entry == null:
		entry = location.get_node_or_null(^"SychSpawn") as Node3D
	if entry:
		sych.global_transform = entry.global_transform
		if sych is CharacterBody3D:
			(sych as CharacterBody3D).velocity = Vector3.ZERO

# --- Бесшовный стриминг --------------------------------------------------

func set_stream_container(node: Node) -> void:
	_stream_container = node

func _resolve_stream_container() -> Node:
	if is_instance_valid(_stream_container):
		return _stream_container
	_stream_container = get_tree().get_first_node_in_group(&"stream_container")
	return _stream_container

## Загружена ли локация (текущая дискретная зона или что-то застримленное).
func is_loaded(id: StringName) -> bool:
	return id == current_location_id or _streamed.has(id) or _in_place_open.has(id)

func get_loaded(id: StringName) -> Node:
	if id == current_location_id:
		return current_location
	return _streamed.get(id, null)

## Сыч физически вошёл в локацию — обновляем «текущую» для крошек.
func notify_sych_entered(id: StringName) -> void:
	if id == &"" or id == _breadcrumb_location_id:
		return
	_breadcrumb_location_id = id
	location_entered.emit(id)

## Открыть кабинет, который уже стоит в меше: вывеска + проём, без стрима заглушки.
func open_in_place_cabinet(door: Node) -> void:
	var target: StringName = door.target_location_id
	if target == &"":
		return
	var anchor: Node3D = null
	var path = door.get("sign_anchor")
	if path != null and path != NodePath():
		anchor = door.get_node_or_null(path) as Node3D
	CabinetPool.apply_to_anchor(target, anchor)
	_in_place_open[target] = true
	mark_opened(target)
	door.set_open(true)
	if door.has_method("refresh_label"):
		door.refresh_label()


## Открыть дверь-стример: подгрузить соседа за ней и пристыковать к проёму.
func open_streaming_door(door: Node) -> void:
	var target: StringName = door.target_location_id
	if target == &"":
		return
	if is_loaded(target):
		door.set_open(true)
		return
	var def := LocationRegistry.get_def(target)
	if def == null or not def.has_scene():
		push_error("[LocationManager] Нельзя застримить: %s" % target)
		return
	var packed: PackedScene = load(def.scene_path)
	if packed == null:
		return
	var inst := packed.instantiate()
	var container := _resolve_stream_container()
	if container == null:
		push_error("[LocationManager] Нет контейнера стриминга.")
		inst.queue_free()
		return
	container.add_child(inst)  # _ready строит двери локации
	CabinetPool.apply(inst)
	var owner_id: StringName = door.owner_location_id()
	var ret: Node3D = _find_return_door(inst, owner_id)
	var inst3d := inst as Node3D
	var door3d := door as Node3D
	if ret != null:
		# Ставим соседа так, чтобы его дверь назад совпала с нашим проёмом
		# (спина к спине, +Z развёрнут на 180°).
		var flip := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
		var ret_local: Transform3D = inst3d.global_transform.affine_inverse() * ret.global_transform
		inst3d.global_transform = door3d.global_transform * flip * ret_local.affine_inverse()
		ret.set_open(true)
	else:
		inst3d.global_transform = door3d.global_transform
		push_warning("[LocationManager] В %s нет двери назад к %s" % [target, owner_id])
	_streamed[target] = inst
	mark_opened(target)
	door.set_open(true)
	_refresh_door_label(door, target)

func _refresh_door_label(door: Node, target: StringName) -> void:
	if not CabinetPool.is_cabinet_slot(target):
		return
	var cabinet_id: StringName = CabinetPool.get_selected_cabinet(target)
	if cabinet_id == &"":
		return
	if door.has_method("refresh_label"):
		door.refresh_label()


func _find_return_door(node: Node, owner_id: StringName) -> Node3D:
	for child in node.get_children():
		if child is StreamingDoor and child.target_location_id == owner_id:
			return child
		var found := _find_return_door(child, owner_id)
		if found != null:
			return found
	return null

## Выгрузить застримленные сцены. Открытые сегодня двери помним до конца дня.
func reset_streamed() -> void:
	for id in _streamed:
		var n = _streamed[id]
		if is_instance_valid(n):
			n.queue_free()
	_streamed.clear()
	_in_place_open.clear()
	_breadcrumb_location_id = &""


func mark_opened(id: StringName) -> void:
	if id != &"":
		_opened_today[id] = true


func was_opened_today(id: StringName) -> bool:
	return id != &"" and _opened_today.has(id)


func forget_opened_today() -> void:
	_opened_today.clear()


func _on_day_ended(_day: int) -> void:
	_opened_today.clear()
	reset_streamed()
	if current_location_id != HOME:
		travel_to(HOME)

# --- Затемнение ----------------------------------------------------------

func _ensure_fade() -> void:
	if is_instance_valid(_fade_layer):
		return
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = FADE_LAYER
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade_rect)

func _set_fade(alpha: float) -> void:
	if _fade_rect:
		_fade_rect.color.a = alpha

func _fade(target_alpha: float) -> void:
	if _fade_rect == null:
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade_rect, "color:a", target_alpha, FADE_TIME)
	await tween.finished
