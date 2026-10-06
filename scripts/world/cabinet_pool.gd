extends Node

## Пул кабинетов. Слот кабинета пустой, пока не открыли дверь: тогда система роллит
## выбор кабинетов по правилам крыла и этажа, игрок вытаскивает один, в кабинете
## появляется 3D-вывеска. Перероллить Шарагу — в начале каждого дня.
## 1 этаж: демонолог только справа. 2 этаж: библиотека только справа;
## актовый зал 30% на каждый ролл выбора, любое крыло; столовая в любом;
## спортзал после столовой. Classroom — базовый кабинет, без условий, оба этажа,
## сколько угодно раз. Выбор кабинетов общий на крыло этажа, всегда из двух.

enum Wing { FIRST_FLOOR_LEFT, FIRST_FLOOR_RIGHT, SECOND_FLOOR_LEFT, SECOND_FLOOR_RIGHT }

signal cabinet_selected(slot_id: StringName, cabinet_id: StringName)

const HISTORIAN_SCENE := preload("res://scenes/actors/npcs/historian.tscn")
const KOTIK_SCENE := preload("res://scenes/actors/npcs/kotik.tscn")
const HISTORIAN_CABINET_GROUP := "historian_cabinet"
const LIBRARY_CABINET_GROUP := "library_cabinet"

const CABINET_SLOT_WING := {
	&"cabinet_slot_1": Wing.FIRST_FLOOR_LEFT,
	&"cabinet_slot_2": Wing.FIRST_FLOOR_LEFT,
	&"cabinet_slot_3": Wing.FIRST_FLOOR_LEFT,
	&"cabinet_slot_4": Wing.FIRST_FLOOR_RIGHT,
	&"cabinet_slot_5": Wing.FIRST_FLOOR_RIGHT,
	&"cabinet_slot_6": Wing.FIRST_FLOOR_RIGHT,
	&"cabinet_slot_7": Wing.SECOND_FLOOR_LEFT,
	&"cabinet_slot_8": Wing.SECOND_FLOOR_LEFT,
	&"cabinet_slot_9": Wing.SECOND_FLOOR_RIGHT,
	&"cabinet_slot_10": Wing.SECOND_FLOOR_RIGHT,
}

const CABINET_TITLE := {
	&"demonologist": "Демонолог",
	&"toilet": "Туалет",
	&"greenhouse": "Оранжерея",
	&"historian_cabinet": "Кабинет Историка",
	&"classroom": "Classroom",
	&"library": "Библиотека",
	&"assembly_hall": "Актовый зал",
	&"cafeteria": "Столовая",
	&"gym": "Спортзал",
}

const CABINET_MODEL := {
	&"demonologist": "res://assets/models/cabinets/demonologist.glb",
	&"toilet": "res://assets/models/cabinets/toilet.glb",
	&"greenhouse": "res://assets/models/cabinets/greenhouse.glb",
	&"historian_cabinet": "res://assets/models/cabinets/historian_cabinet.glb",
	&"classroom": "res://assets/models/cabinets/classroom.glb",
	&"library": "res://assets/models/cabinets/library.glb",
	&"assembly_hall": "res://assets/models/cabinets/assembly_hall.glb",
	&"cafeteria": "res://assets/models/cabinets/cafeteria.glb",
	&"gym": "res://assets/models/cabinets/gym.glb",
}

const FIRST_FLOOR_CABINETS: Array[StringName] = [
	&"demonologist", &"toilet", &"greenhouse", &"historian_cabinet", &"classroom",
]
const SECOND_FLOOR_CABINETS: Array[StringName] = [
	&"library", &"assembly_hall", &"cafeteria", &"gym", &"classroom",
]

const GREENHOUSE_RIGHT_CHANCE := 0.7
const ASSEMBLY_HALL_CHANCE := 0.3
const CABINET_CHOICE_SIZE := 2

const CABINET_ENERGINKA_COST := {
	&"demonologist": 2,
	&"library": 2,
	&"toilet": 1,
	&"greenhouse": 1,
	&"historian_cabinet": 1,
	&"classroom": 1,
	&"assembly_hall": 1,
	&"cafeteria": 1,
	&"gym": 1,
}

## Базовые кабинеты: повторяются сколько угодно раз и не исключаются после вытаскивания.
const BASE_CABINETS := {
	&"classroom": true,
}

var _rng := RandomNumberGenerator.new()
var _greenhouse_right: bool = true
var _selected: Dictionary = {}  # StringName slot -> StringName cabinet ("" = открыт, пусто)
var _used: Dictionary = {}   # StringName cabinet -> true
var _wing_cabinet_choices: Dictionary = {}  # Wing -> Array[StringName]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DaySystem.day_started.connect(_on_day_started)
	if not BranchSystem.branch_stage_planned.is_connected(_on_branch_stage_planned):
		BranchSystem.branch_stage_planned.connect(_on_branch_stage_planned)
	reroll_sharaga()


func _on_day_started(_day: int) -> void:
	reroll_sharaga()


## Перероллить Шарагу: сбросить кабинеты в слотах и состояние генерации.
func reroll_sharaga() -> void:
	_selected.clear()
	_used.clear()
	_wing_cabinet_choices.clear()
	randomize()
	_rng.seed = Time.get_ticks_usec() ^ (Time.get_unix_time_from_system() as int)
	_greenhouse_right = _rng.randf() < GREENHOUSE_RIGHT_CHANCE
	LocationManager.forget_opened_today()


func is_base_cabinet(cabinet_id: StringName) -> bool:
	return BASE_CABINETS.has(cabinet_id)


func is_taken(cabinet_id: StringName) -> bool:
	return cabinet_id != &"" and _used.has(cabinet_id) and not is_base_cabinet(cabinet_id)


func _mark_taken(cabinet_id: StringName) -> void:
	if not is_base_cabinet(cabinet_id):
		_used[cabinet_id] = true


func is_cabinet_slot(location_id: StringName) -> bool:
	return CABINET_SLOT_WING.has(location_id)


func get_selected_cabinet(slot_id: StringName) -> StringName:
	return _selected.get(slot_id, &"")


func has_selected_cabinet(slot_id: StringName) -> bool:
	return _selected.has(slot_id)


func cabinet_title(cabinet_id: StringName) -> String:
	return CABINET_TITLE.get(cabinet_id, String(cabinet_id))


func energinka_cost(cabinet_id: StringName) -> int:
	return int(CABINET_ENERGINKA_COST.get(cabinet_id, 1))


## Выбор кабинетов крыла для этой двери. Все закрытые двери крыла видят одну пару.
## Занятые специальные кабинеты из пары выкидываются; пустой выбор = пустой кабинет.
func cabinet_choice_for(slot_id: StringName) -> Array[StringName]:
	if not is_cabinet_slot(slot_id):
		return []
	if _selected.has(slot_id):
		return []
	var wing: int = CABINET_SLOT_WING[slot_id]
	if _wing_cabinet_choices.has(wing) and _cabinet_choice_has_taken(_wing_cabinet_choices[wing]):
		_wing_cabinet_choices.erase(wing)
		_reroll_wing_cabinet_choice(wing)
	if not _wing_cabinet_choices.has(wing):
		var fresh := _roll_cabinet_choice(wing)
		if fresh.is_empty():
			return []
		_wing_cabinet_choices[wing] = fresh
	return _wing_cabinet_choices[wing].duplicate()


## Вытащить кабинет: зафиксировать выбор игрока в слоте. Невыбранный вариант остаётся в пуле.
## Специальный кабинет не открывается второй раз: такой слот становится пустым.
func select_cabinet(slot_id: StringName, cabinet_id: StringName) -> bool:
	if not is_cabinet_slot(slot_id):
		return false
	if _selected.has(slot_id) and _selected[slot_id] != &"":
		return _selected[slot_id] == cabinet_id
	if _selected.has(slot_id) and _selected[slot_id] == &"":
		return cabinet_id == &""
	if cabinet_id != &"" and _used.has(cabinet_id) and not is_base_cabinet(cabinet_id):
		cabinet_id = &""
	if cabinet_id == &"":
		return _select_empty(slot_id)
	var wing: int = CABINET_SLOT_WING[slot_id]
	var choice: Array[StringName] = _wing_cabinet_choices.get(wing, [] as Array[StringName])
	if not choice.is_empty() and not choice.has(cabinet_id):
		return false
	if choice.is_empty() and not _allowed_cabinets(wing).has(cabinet_id):
		return false
	_selected[slot_id] = cabinet_id
	_mark_taken(cabinet_id)
	_reroll_wing_cabinet_choice(wing)
	_invalidate_stale_cabinet_choices()
	cabinet_selected.emit(slot_id, cabinet_id)
	print("[CabinetPool] %s (%s) → %s" % [slot_id, _wing_title(wing), cabinet_title(cabinet_id)])
	return true


func _select_empty(slot_id: StringName) -> bool:
	_selected[slot_id] = &""
	_reroll_wing_cabinet_choice(CABINET_SLOT_WING[slot_id])
	cabinet_selected.emit(slot_id, &"")
	print("[CabinetPool] %s (%s) → пусто" % [slot_id, _wing_title(CABINET_SLOT_WING[slot_id])])
	return true


func is_empty_cabinet(slot_id: StringName) -> bool:
	return _selected.has(slot_id) and _selected[slot_id] == &""


## Роллить выбор кабинетов: пара из двух разных допустимых кабинетов крыла.
func _roll_cabinet_choice(wing: int) -> Array[StringName]:
	var allowed := _allowed_cabinets(wing)
	# Редкость — на этот ролл, не на день: актовый зал бросается заново.
	if allowed.has(&"assembly_hall") and _rng.randf() >= ASSEMBLY_HALL_CHANCE:
		allowed.erase(&"assembly_hall")
	if allowed.is_empty():
		return []
	allowed.shuffle()
	var choice: Array[StringName] = []
	var n: int = mini(CABINET_CHOICE_SIZE, allowed.size())
	for i in range(n):
		choice.append(allowed[i])
	return choice


func _reroll_wing_cabinet_choice(wing: int) -> void:
	_wing_cabinet_choices.erase(wing)
	if not _wing_has_closed_slot(wing):
		return
	var choice := _roll_cabinet_choice(wing)
	if not choice.is_empty():
		_wing_cabinet_choices[wing] = choice


func _invalidate_stale_cabinet_choices() -> void:
	var stale: Array = []
	for wing in _wing_cabinet_choices:
		if _cabinet_choice_has_taken(_wing_cabinet_choices[wing]):
			stale.append(wing)
	for wing in stale:
		_reroll_wing_cabinet_choice(wing)


func _cabinet_choice_has_taken(choice: Array) -> bool:
	for cabinet_id in choice:
		if _used.has(cabinet_id) and not is_base_cabinet(cabinet_id):
			return true
	return false


func _wing_has_closed_slot(wing: int) -> bool:
	for slot_id in CABINET_SLOT_WING:
		if CABINET_SLOT_WING[slot_id] != wing:
			continue
		if not _selected.has(slot_id) or _selected[slot_id] == &"":
			return true
	return false


func display_title(location_id: StringName) -> String:
	var selected: StringName = get_selected_cabinet(location_id)
	if selected != &"":
		return cabinet_title(selected)
	return LocationRegistry.get_title(location_id)


## Подпись на двери: пока слот не открыт — «?», после вытаскивания — имя кабинета.
func door_label(location_id: StringName) -> String:
	if is_cabinet_slot(location_id):
		var selected: StringName = get_selected_cabinet(location_id)
		return cabinet_title(selected) if selected != &"" else "?"
	return LocationRegistry.get_title(location_id)


## Вытащить кабинет для слота (идемпотентно) и поставить 3D-вывеску в сцену.
func apply(location: Node) -> StringName:
	var slot: StringName = location.get("location_id")
	if not is_cabinet_slot(slot):
		return &""
	var cabinet_id := select_random_cabinet_for(slot)
	if cabinet_id == &"":
		return &""
	var title := cabinet_title(cabinet_id)
	location.set("display_name", title)
	var old_title := location.get_node_or_null(^"Title") as Label3D
	if old_title:
		old_title.visible = false
		old_title.text = ""
	var host: Node3D = location as Node3D
	if host:
		_spawn_sign(host, cabinet_id)
	return cabinet_id


## Поставить 3D-вывеску в якорь. Кабинет должен быть уже вытащен через select_cabinet().
func apply_to_anchor(slot_id: StringName, anchor: Node3D) -> StringName:
	if not is_cabinet_slot(slot_id) or anchor == null:
		return &""
	var cabinet_id: StringName = get_selected_cabinet(slot_id)
	if cabinet_id == &"":
		return &""
	_spawn_sign(anchor, cabinet_id)
	return cabinet_id


func _spawn_sign(host: Node3D, cabinet_id: StringName) -> void:
	if host.get_node_or_null(^"CabinetSign") == null:
		var path: String = CABINET_MODEL.get(cabinet_id, "")
		if path.is_empty() or not ResourceLoader.exists(path):
			push_warning("[CabinetPool] Нет модели: %s" % path)
		else:
			var packed: PackedScene = load(path)
			if packed != null:
				var sign := packed.instantiate() as Node3D
				sign.name = "CabinetSign"
				sign.scale = Vector3.ZERO
				host.add_child(sign)
				var tween := host.create_tween()
				tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				tween.tween_property(sign, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if cabinet_id == &"historian_cabinet":
		host.add_to_group(HISTORIAN_CABINET_GROUP)
		place_historian(host)
	elif cabinet_id == &"library":
		host.add_to_group(LIBRARY_CABINET_GROUP)
		place_kotik(host)


func _on_branch_stage_planned(branch_stage_id: String) -> void:
	if branch_stage_id == BranchSystem.BRANCH_STAGE_FIND_HISTORIAN:
		_place_branch_stage_npc(HISTORIAN_CABINET_GROUP, place_historian)
	elif branch_stage_id == BranchSystem.BRANCH_STAGE_FIND_KOTIK:
		_place_branch_stage_npc(LIBRARY_CABINET_GROUP, place_kotik)


func _place_branch_stage_npc(group_name: String, place: Callable) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(group_name):
		if node is Node3D:
			place.call(node)


## Историк появляется в открытом кабинете Историка, пока этап ветки активен.
## SignAnchor на высоте центра кабинета; ноги ставим на пол крыла первого этажа (≈ -0.03).
const HISTORIAN_FLOOR_Y := -0.03

func place_historian(host: Node3D) -> void:
	if host == null:
		return
	if BranchSystem.get_state(BranchSystem.BRANCH_STAGE_FIND_HISTORIAN) < BranchSystem.State.ACTIVE:
		return
	if host.get_node_or_null(^"Historian") != null:
		return
	var npc := HISTORIAN_SCENE.instantiate() as Node3D
	npc.name = "Historian"
	host.add_child(npc)
	if host is Marker3D:
		npc.position = Vector3(0.0, -host.position.y + HISTORIAN_FLOOR_Y, 0.8)


## Котик появляется в библиотеке, когда этап ветки активен и кабинет уже открыт.
## Якорь вывески на 1.36 м выше пола и на втором этаже тоже.
const SIGN_ABOVE_FLOOR := 1.36

func place_kotik(host: Node3D) -> void:
	if host == null:
		return
	if BranchSystem.get_state(BranchSystem.BRANCH_STAGE_FIND_KOTIK) < BranchSystem.State.ACTIVE:
		return
	if host.get_node_or_null(^"Kotik") != null:
		return
	var npc := KOTIK_SCENE.instantiate() as Node3D
	npc.name = "Kotik"
	npc.set("hidden_until_revealed", false)
	host.add_child(npc)
	npc.visible = true
	if host is Marker3D:
		npc.position = Vector3(0.0, -SIGN_ABOVE_FLOOR, 0.8)


## Вытащить случайный кабинет из выбора для слота (без участия игрока).
func select_random_cabinet_for(slot_id: StringName) -> StringName:
	if _selected.has(slot_id):
		return _selected[slot_id]
	if not CABINET_SLOT_WING.has(slot_id):
		return &""
	var choice := cabinet_choice_for(slot_id)
	if choice.is_empty():
		_selected[slot_id] = &""
		return &""
	var cabinet_id: StringName = choice[_rng.randi_range(0, choice.size() - 1)]
	_selected[slot_id] = cabinet_id
	_mark_taken(cabinet_id)
	_reroll_wing_cabinet_choice(CABINET_SLOT_WING[slot_id])
	cabinet_selected.emit(slot_id, cabinet_id)
	print("[CabinetPool] %s (%s) → %s" % [
		slot_id,
		_wing_title(CABINET_SLOT_WING[slot_id]),
		cabinet_title(cabinet_id),
	])
	return cabinet_id


## Допустимый набор кабинетов для крыла с учётом текущего состояния генерации.
func _allowed_cabinets(wing: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for cabinet_id in (SECOND_FLOOR_CABINETS if is_second_floor(wing) else FIRST_FLOOR_CABINETS):
		if _used.has(cabinet_id):
			continue
		if cabinet_id == &"historian_cabinet" and not _used.has(&"demonologist"):
			continue
		if cabinet_id == &"gym" and not _used.has(&"cafeteria"):
			continue
		if not _allowed_in_wing(cabinet_id, wing):
			continue
		out.append(cabinet_id)
	return out


func is_left_wing(wing: int) -> bool:
	return wing == Wing.FIRST_FLOOR_LEFT or wing == Wing.SECOND_FLOOR_LEFT


func is_second_floor(wing: int) -> bool:
	return wing == Wing.SECOND_FLOOR_LEFT or wing == Wing.SECOND_FLOOR_RIGHT


func _wing_title(wing: int) -> String:
	match wing:
		Wing.FIRST_FLOOR_LEFT:
			return "1 этаж, левое крыло"
		Wing.FIRST_FLOOR_RIGHT:
			return "1 этаж, правое крыло"
		Wing.SECOND_FLOOR_LEFT:
			return "2 этаж, левое крыло"
		Wing.SECOND_FLOOR_RIGHT:
			return "2 этаж, правое крыло"
		_:
			return "?"


func _allowed_in_wing(cabinet_id: StringName, wing: int) -> bool:
	match cabinet_id:
		&"demonologist":
			return wing == Wing.FIRST_FLOOR_RIGHT
		&"library":
			return wing == Wing.SECOND_FLOOR_RIGHT
		&"greenhouse":
			return not is_second_floor(wing) and is_left_wing(wing) != _greenhouse_right
		&"assembly_hall", &"cafeteria", &"gym":
			return is_second_floor(wing)
		&"toilet", &"historian_cabinet":
			return not is_second_floor(wing)
		&"classroom":
			return true
		_:
			return true
