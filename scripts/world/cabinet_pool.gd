extends Node

## Пул имён кабинетов. Слот пустой, пока не открыли дверь: тогда из пула
## вытягивается имя по правилам крыла и этажа, в комнате появляется 3D-название.
## Сброс — в начале каждого дня.
## 1 этаж: демонолог только справа. 2 этаж: библиотека только справа;
## актовый зал 30% на каждый драфт двери, любое крыло; столовая в любом;
## спортзал после столовой. Classroom — частая, без условий, оба этажа,
## сколько угодно раз. Драфт общий на крыло этажа, всегда из двух.

enum Wing { F1_LEFT, F1_RIGHT, F2_LEFT, F2_RIGHT }

signal room_drawn(slot_id: StringName, room_id: StringName)

const HISTORIAN_SCENE := preload("res://scenes/actors/npcs/historian.tscn")
const KOTIK_SCENE := preload("res://scenes/actors/npcs/kotik.tscn")
const HISTORY_ROOM_GROUP := "history_room"
const LIBRARY_ROOM_GROUP := "library_room"

const SLOT_WING := {
	&"kabinet_1": Wing.F1_LEFT,
	&"kabinet_2": Wing.F1_LEFT,
	&"kabinet_3": Wing.F1_LEFT,
	&"kabinet_4": Wing.F1_RIGHT,
	&"kabinet_5": Wing.F1_RIGHT,
	&"kabinet_6": Wing.F1_RIGHT,
	&"kabinet_7": Wing.F2_LEFT,
	&"kabinet_8": Wing.F2_LEFT,
	&"kabinet_9": Wing.F2_RIGHT,
	&"kabinet_10": Wing.F2_RIGHT,
}

const ROOM_TITLE := {
	&"demonologist": "Демонолог",
	&"lavatory": "Туалет",
	&"greenhouse": "Оранжерея",
	&"history": "Кабинет истории",
	&"classroom": "Кабинет",
	&"library": "Библиотека",
	&"assembly": "Актовый зал",
	&"cafeteria": "Столовая",
	&"gym": "Спортзал",
}

const ROOM_MODEL := {
	&"demonologist": "res://assets/models/rooms/demonologist.glb",
	&"lavatory": "res://assets/models/rooms/lavatory.glb",
	&"greenhouse": "res://assets/models/rooms/greenhouse.glb",
	&"history": "res://assets/models/rooms/history.glb",
	&"classroom": "res://assets/models/rooms/classroom.glb",
	&"library": "res://assets/models/rooms/library.glb",
	&"assembly": "res://assets/models/rooms/assembly.glb",
	&"cafeteria": "res://assets/models/rooms/cafeteria.glb",
	&"gym": "res://assets/models/rooms/gym.glb",
}

const F1_ROOMS: Array[StringName] = [
	&"demonologist", &"lavatory", &"greenhouse", &"history", &"classroom",
]
const F2_ROOMS: Array[StringName] = [
	&"library", &"assembly", &"cafeteria", &"gym", &"classroom",
]

const GREENHOUSE_RIGHT_CHANCE := 0.7
const ASSEMBLY_CHANCE := 0.3
const OFFER_SIZE := 2

const ROOM_COST := {
	&"demonologist": 2,
	&"library": 2,
	&"lavatory": 1,
	&"greenhouse": 1,
	&"history": 1,
	&"classroom": 1,
	&"assembly": 1,
	&"cafeteria": 1,
	&"gym": 1,
}

const REPEATABLE := {
	&"classroom": true,
}

var _rng := RandomNumberGenerator.new()
var _greenhouse_right: bool = true
var _drawn: Dictionary = {}  # StringName slot -> StringName room ("" = открыт, пусто)
var _used: Dictionary = {}   # StringName room -> true
var _wing_offers: Dictionary = {}  # Wing -> Array[StringName]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DaySystem.day_started.connect(_on_day_started)
	if not QuestSystem.quest_spawned.is_connected(_on_quest_spawned):
		QuestSystem.quest_spawned.connect(_on_quest_spawned)
	_reset_day()


func _on_day_started(_day: int) -> void:
	_reset_day()


func _reset_day() -> void:
	_drawn.clear()
	_used.clear()
	_wing_offers.clear()
	randomize()
	_rng.seed = Time.get_ticks_usec() ^ (Time.get_unix_time_from_system() as int)
	_greenhouse_right = _rng.randf() < GREENHOUSE_RIGHT_CHANCE
	LocationManager.forget_opened_today()


func is_repeatable(room_id: StringName) -> bool:
	return REPEATABLE.has(room_id)


func is_taken(room_id: StringName) -> bool:
	return room_id != &"" and _used.has(room_id) and not is_repeatable(room_id)


func _mark_taken(room_id: StringName) -> void:
	if not is_repeatable(room_id):
		_used[room_id] = true


func is_slot(location_id: StringName) -> bool:
	return SLOT_WING.has(location_id)


func get_drawn(slot_id: StringName) -> StringName:
	return _drawn.get(slot_id, &"")


func is_committed(slot_id: StringName) -> bool:
	return _drawn.has(slot_id)


func room_title(room_id: StringName) -> String:
	return ROOM_TITLE.get(room_id, String(room_id))


func entry_cost(room_id: StringName) -> int:
	return int(ROOM_COST.get(room_id, 1))


## Драфт крыла для этой двери. Все закрытые двери крыла видят одну пару.
## Занятые уникальные комнаты из пары выкидываются; пустой оффер = пустая комната.
func offer_for(slot_id: StringName) -> Array[StringName]:
	if not is_slot(slot_id):
		return []
	if _drawn.has(slot_id):
		return []
	var wing: int = SLOT_WING[slot_id]
	if _wing_offers.has(wing) and _offer_has_taken(_wing_offers[wing]):
		_wing_offers.erase(wing)
		_rebuild_wing_offer(wing)
	if not _wing_offers.has(wing):
		var fresh := _make_offer(wing)
		if fresh.is_empty():
			return []
		_wing_offers[wing] = fresh
	return _wing_offers[wing].duplicate()


## Зафиксировать выбор игрока. Невыбранный вариант остаётся в пуле.
## Уникальная комната не открывается второй раз: такой слот становится пустым.
func commit(slot_id: StringName, room_id: StringName) -> bool:
	if not is_slot(slot_id):
		return false
	if _drawn.has(slot_id) and _drawn[slot_id] != &"":
		return _drawn[slot_id] == room_id
	if _drawn.has(slot_id) and _drawn[slot_id] == &"":
		return room_id == &""
	if room_id != &"" and _used.has(room_id) and not is_repeatable(room_id):
		room_id = &""
	if room_id == &"":
		return _commit_empty(slot_id)
	var wing: int = SLOT_WING[slot_id]
	var offer: Array[StringName] = _wing_offers.get(wing, [] as Array[StringName])
	if not offer.is_empty() and not offer.has(room_id):
		return false
	if offer.is_empty() and not _eligible(wing).has(room_id):
		return false
	_drawn[slot_id] = room_id
	_mark_taken(room_id)
	_rebuild_wing_offer(wing)
	_invalidate_stale_offers()
	room_drawn.emit(slot_id, room_id)
	print("[RoomPool] %s (%s) → %s" % [slot_id, _wing_title(wing), room_title(room_id)])
	return true


func _commit_empty(slot_id: StringName) -> bool:
	_drawn[slot_id] = &""
	_rebuild_wing_offer(SLOT_WING[slot_id])
	room_drawn.emit(slot_id, &"")
	print("[RoomPool] %s (%s) → пусто" % [slot_id, _wing_title(SLOT_WING[slot_id])])
	return true


func is_empty_room(slot_id: StringName) -> bool:
	return _drawn.has(slot_id) and _drawn[slot_id] == &""


func _make_offer(wing: int) -> Array[StringName]:
	var eligible := _eligible(wing)
	# Редкость — на этот драфт, не на день: актовый зал бросается заново.
	if eligible.has(&"assembly") and _rng.randf() >= ASSEMBLY_CHANCE:
		eligible.erase(&"assembly")
	if eligible.is_empty():
		return []
	eligible.shuffle()
	var offer: Array[StringName] = []
	var n: int = mini(OFFER_SIZE, eligible.size())
	for i in range(n):
		offer.append(eligible[i])
	return offer


func _rebuild_wing_offer(wing: int) -> void:
	_wing_offers.erase(wing)
	if not _wing_has_closed_slot(wing):
		return
	var offer := _make_offer(wing)
	if not offer.is_empty():
		_wing_offers[wing] = offer


func _invalidate_stale_offers() -> void:
	var stale: Array = []
	for wing in _wing_offers:
		if _offer_has_taken(_wing_offers[wing]):
			stale.append(wing)
	for wing in stale:
		_rebuild_wing_offer(wing)


func _offer_has_taken(offer: Array) -> bool:
	for room_id in offer:
		if _used.has(room_id) and not is_repeatable(room_id):
			return true
	return false


func _wing_has_closed_slot(wing: int) -> bool:
	for slot_id in SLOT_WING:
		if SLOT_WING[slot_id] != wing:
			continue
		if not _drawn.has(slot_id) or _drawn[slot_id] == &"":
			return true
	return false


func display_title(location_id: StringName) -> String:
	var drawn: StringName = get_drawn(location_id)
	if drawn != &"":
		return room_title(drawn)
	return LocationRegistry.get_title(location_id)


## Подпись на двери: пока слот не открыт — «?», после вытягивания — имя.
func door_label(location_id: StringName) -> String:
	if is_slot(location_id):
		var drawn: StringName = get_drawn(location_id)
		return room_title(drawn) if drawn != &"" else "?"
	return LocationRegistry.get_title(location_id)


## Вытянуть имя для слота (идемпотентно) и поставить 3D-название в сцену.
func apply(location: Node) -> StringName:
	var slot: StringName = location.get("location_id")
	if not is_slot(slot):
		return &""
	var room_id := draw_for(slot)
	if room_id == &"":
		return &""
	var title := room_title(room_id)
	location.set("display_name", title)
	var old_title := location.get_node_or_null(^"Title") as Label3D
	if old_title:
		old_title.visible = false
		old_title.text = ""
	var host: Node3D = location as Node3D
	if host:
		_spawn_sign(host, room_id)
	return room_id


## Поставить 3D-вывеску в якорь. Имя должно быть уже выбрано через commit().
func apply_to_anchor(slot_id: StringName, anchor: Node3D) -> StringName:
	if not is_slot(slot_id) or anchor == null:
		return &""
	var room_id: StringName = get_drawn(slot_id)
	if room_id == &"":
		return &""
	_spawn_sign(anchor, room_id)
	return room_id


func _spawn_sign(host: Node3D, room_id: StringName) -> void:
	if host.get_node_or_null(^"RoomSign") == null:
		var path: String = ROOM_MODEL.get(room_id, "")
		if path.is_empty() or not ResourceLoader.exists(path):
			push_warning("[RoomPool] Нет модели: %s" % path)
		else:
			var packed: PackedScene = load(path)
			if packed != null:
				var sign := packed.instantiate() as Node3D
				sign.name = "RoomSign"
				sign.scale = Vector3.ZERO
				host.add_child(sign)
				var tween := host.create_tween()
				tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				tween.tween_property(sign, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if room_id == &"history":
		host.add_to_group(HISTORY_ROOM_GROUP)
		place_historian(host)
	elif room_id == &"library":
		host.add_to_group(LIBRARY_ROOM_GROUP)
		place_kotik(host)


func _on_quest_spawned(quest_id: String) -> void:
	if quest_id == QuestSystem.QUEST_FIND_HISTORIAN:
		_place_quest_npc(HISTORY_ROOM_GROUP, place_historian)
	elif quest_id == QuestSystem.QUEST_FIND_KOTIK:
		_place_quest_npc(LIBRARY_ROOM_GROUP, place_kotik)


func _place_quest_npc(group_name: String, place: Callable) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for node in tree.get_nodes_in_group(group_name):
		if node is Node3D:
			place.call(node)


## Историк появляется в открытом кабинете истории, пока квест взят.
## SignAnchor на высоте центра комнаты; ноги ставим на пол крыла первого этажа (≈ -0.03).
const HISTORIAN_FLOOR_Y := -0.03

func place_historian(host: Node3D) -> void:
	if host == null:
		return
	if QuestSystem.get_state(QuestSystem.QUEST_FIND_HISTORIAN) < QuestSystem.State.ACTIVE:
		return
	if host.get_node_or_null(^"Historian") != null:
		return
	var npc := HISTORIAN_SCENE.instantiate() as Node3D
	npc.name = "Historian"
	host.add_child(npc)
	if host is Marker3D:
		npc.position = Vector3(0.0, -host.position.y + HISTORIAN_FLOOR_Y, 0.8)


## Котик появляется в библиотеке, когда квест взят и комната уже открыта.
## Якорь вывески на 1.36 м выше пола и на втором этаже тоже.
const SIGN_ABOVE_FLOOR := 1.36

func place_kotik(host: Node3D) -> void:
	if host == null:
		return
	if QuestSystem.get_state(QuestSystem.QUEST_FIND_KOTIK) < QuestSystem.State.ACTIVE:
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


func draw_for(slot_id: StringName) -> StringName:
	if _drawn.has(slot_id):
		return _drawn[slot_id]
	if not SLOT_WING.has(slot_id):
		return &""
	var offer := offer_for(slot_id)
	if offer.is_empty():
		_drawn[slot_id] = &""
		return &""
	var room_id: StringName = offer[_rng.randi_range(0, offer.size() - 1)]
	_drawn[slot_id] = room_id
	_mark_taken(room_id)
	_rebuild_wing_offer(SLOT_WING[slot_id])
	room_drawn.emit(slot_id, room_id)
	print("[RoomPool] %s (%s) → %s" % [
		slot_id,
		_wing_title(SLOT_WING[slot_id]),
		room_title(room_id),
	])
	return room_id


func _eligible(wing: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for room_id in (F2_ROOMS if is_floor2(wing) else F1_ROOMS):
		if _used.has(room_id):
			continue
		if room_id == &"history" and not _used.has(&"demonologist"):
			continue
		if room_id == &"gym" and not _used.has(&"cafeteria"):
			continue
		if not _allowed_in_wing(room_id, wing):
			continue
		out.append(room_id)
	return out


func is_left(wing: int) -> bool:
	return wing == Wing.F1_LEFT or wing == Wing.F2_LEFT


func is_floor2(wing: int) -> bool:
	return wing == Wing.F2_LEFT or wing == Wing.F2_RIGHT


func _wing_title(wing: int) -> String:
	match wing:
		Wing.F1_LEFT:
			return "1эт лево"
		Wing.F1_RIGHT:
			return "1эт право"
		Wing.F2_LEFT:
			return "2эт лево"
		Wing.F2_RIGHT:
			return "2эт право"
		_:
			return "?"


func _allowed_in_wing(room_id: StringName, wing: int) -> bool:
	match room_id:
		&"demonologist":
			return wing == Wing.F1_RIGHT
		&"library":
			return wing == Wing.F2_RIGHT
		&"greenhouse":
			return not is_floor2(wing) and is_left(wing) != _greenhouse_right
		&"assembly", &"cafeteria", &"gym":
			return is_floor2(wing)
		&"lavatory", &"history":
			return not is_floor2(wing)
		&"classroom":
			return true
		_:
			return true
