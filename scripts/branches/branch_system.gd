extends Node
## Глобальная система квестов. Autoload (см. project.godot → [autoload] QuestSystem).
##
## Каждый квест привязан к ветке (kotik / demonolog) и к слоту на пробковой доске.
## Нижний ряд доски — ветка Демонолога (пока портрет и сердца Лисика).
## Жизненный цикл состояния квеста:
##   EMPTY      — ничего не перетаскивали;
##   PENDING    — энергия перетащена на сердце, но не подтверждена (не нажато «Принять»);
##   ACTIVE     — квест заспавнен (нажато «Принять») → триггерит событие в мире;
##   COMPLETED  — квест выполнен.

enum State { EMPTY, PENDING, ACTIVE, COMPLETED }

const BRANCH_KOTIK := "kotik"
const BRANCH_LISIK := "lisik"
const BRANCH_DEMONOLOG := BRANCH_LISIK

const QUEST_FIND_KOTIK := "find_kotik"
const QUEST_FIND_HISTORIAN := "find_historian"
const QUEST_DEMONOLOG_2 := "demonologist_2"

const HISTORIAN_BOARD_MESSAGE := "До меня дошел слух, что наш жуткий Демонолог был когда-то студентом преподавателя Истории. Проверим из первых рук."
const COMPLETE_BANNER_TEXT := "Ура! Ты выполнил квест!"
const COMPLETE_BANNER_SECONDS := 2.4
const COMPLETE_BANNER_LAYER := 205

## Меняется состояние любого квеста (для обновления UI доски).
signal quest_state_changed(quest_id: String, state: int)
## Квест заспавнен (подтверждён через «Принять») — здесь подвешиваются игровые события.
signal quest_spawned(quest_id: String)
## Квест выполнен.
signal quest_completed(quest_id: String)

var _quests: Dictionary = {}
var _slot_to_quest: Dictionary = {}
var _complete_banner: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_define_quests()


func _define_quests() -> void:
	_define_quest(QUEST_FIND_KOTIK, BRANCH_KOTIK, 0, "Найти Котика и поговорить")
	_define_quest(
		QUEST_FIND_HISTORIAN,
		BRANCH_DEMONOLOG,
		4,
		"Поговорить с преподавателем Истории",
		"",
		HISTORIAN_BOARD_MESSAGE,
	)
	_define_quest(
		QUEST_DEMONOLOG_2,
		BRANCH_DEMONOLOG,
		5,
		"Следующий шаг ветки Демонолога",
		QUEST_FIND_HISTORIAN,
	)


func _define_quest(
	id: String,
	branch: String,
	slot_index: int,
	title: String,
	requires: String = "",
	board_message: String = "",
) -> void:
	_quests[id] = {
		"id": id,
		"branch": branch,
		"slot": slot_index,
		"title": title,
		"requires": requires,
		"board_message": board_message,
		"state": State.EMPTY,
	}
	_slot_to_quest[slot_index] = id


func has_quest_for_slot(slot_index: int) -> bool:
	return _slot_to_quest.has(slot_index)


func get_quest_id_for_slot(slot_index: int) -> String:
	return _slot_to_quest.get(slot_index, "")


func get_state(quest_id: String) -> int:
	if not _quests.has(quest_id):
		return State.EMPTY
	return _quests[quest_id]["state"]


func get_state_for_slot(slot_index: int) -> int:
	var id := get_quest_id_for_slot(slot_index)
	if id == "":
		return State.EMPTY
	return get_state(id)


func get_title(quest_id: String) -> String:
	if not _quests.has(quest_id):
		return ""
	return _quests[quest_id]["title"]


func get_branch(quest_id: String) -> String:
	if not _quests.has(quest_id):
		return ""
	return _quests[quest_id]["branch"]


func is_unlocked(quest_id: String) -> bool:
	if not _quests.has(quest_id):
		return false
	var req: String = _quests[quest_id].get("requires", "")
	if req == "":
		return true
	return get_state(req) == State.COMPLETED


func is_slot_unlocked(slot_index: int) -> bool:
	var id := get_quest_id_for_slot(slot_index)
	if id == "":
		return false
	return is_unlocked(id)


func can_accept_slot(slot_index: int) -> bool:
	var id := get_quest_id_for_slot(slot_index)
	if id == "":
		return false
	return get_state(id) == State.EMPTY and is_unlocked(id)


## Текст, который можно перечитать наведением на сердце после «ок».
## Пока квест не подтверждён, строки нет.
func get_confirmed_description(slot_index: int) -> String:
	var id := get_quest_id_for_slot(slot_index)
	if id == "":
		return ""
	var state := get_state(id)
	if state != State.ACTIVE and state != State.COMPLETED:
		return ""
	var msg: String = _quests[id].get("board_message", "")
	if msg != "":
		return msg
	return get_title(id)


## Ворчание активного квеста. Его говорит AsideSystem снизу экрана, не подпись на доске.
func get_board_message() -> String:
	for id in _quests:
		var q: Dictionary = _quests[id]
		if int(q["state"]) < State.ACTIVE:
			continue
		var msg: String = q.get("board_message", "")
		if msg != "":
			return msg
	return ""


## EMPTY → PENDING (энергия перетащена, но не подтверждена).
func set_pending(quest_id: String) -> bool:
	if not _quests.has(quest_id) or _quests[quest_id]["state"] != State.EMPTY:
		return false
	if not is_unlocked(quest_id):
		return false
	_set_state(quest_id, State.PENDING)
	return true


## PENDING → EMPTY (вернули энергию до подтверждения).
func cancel_pending(quest_id: String) -> bool:
	if not _quests.has(quest_id) or _quests[quest_id]["state"] != State.PENDING:
		return false
	_set_state(quest_id, State.EMPTY)
	return true


func has_pending() -> bool:
	for id in _quests:
		if _quests[id]["state"] == State.PENDING:
			return true
	return false


func get_pending_count() -> int:
	var count := 0
	for id in _quests:
		if _quests[id]["state"] == State.PENDING:
			count += 1
	return count


## Подтверждение («Принять»): все PENDING → ACTIVE. Возвращает список заспавненных id.
func confirm_pending() -> Array:
	var spawned: Array = []
	for id in _quests:
		if _quests[id]["state"] == State.PENDING:
			_set_state(id, State.ACTIVE)
			spawned.append(id)
	for id in spawned:
		quest_spawned.emit(id)
	return spawned


## Любое не завершённое состояние → COMPLETED.
func complete_quest(quest_id: String) -> bool:
	if not _quests.has(quest_id) or _quests[quest_id]["state"] == State.COMPLETED:
		return false
	_set_state(quest_id, State.COMPLETED)
	quest_completed.emit(quest_id)
	show_quest_complete_banner()
	return true


func show_quest_complete_banner() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	if is_instance_valid(_complete_banner):
		_complete_banner.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "QuestCompleteBanner"
	layer.layer = COMPLETE_BANNER_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(layer)
	_complete_banner = layer

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.02, 0.04, 0.48)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var label := Label.new()
	label.name = "Message"
	label.text = COMPLETE_BANNER_TEXT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left = -420.0
	label.offset_top = -80.0
	label.offset_right = 420.0
	label.offset_bottom = 80.0
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 0.94, 0.72, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 10)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(label)

	root.modulate.a = 0.0
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(root, "modulate:a", 1.0, 0.22)
	tween.tween_interval(COMPLETE_BANNER_SECONDS)
	tween.tween_property(root, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
		if _complete_banner == layer:
			_complete_banner = null
	)


func has_confirmed_plan() -> bool:
	for id in _quests:
		if int(_quests[id]["state"]) >= State.ACTIVE:
			return true
	return false


func reset_progress() -> void:
	if is_instance_valid(_complete_banner):
		_complete_banner.queue_free()
	_complete_banner = null
	_quests.clear()
	_slot_to_quest.clear()
	_define_quests()
	for id in _quests:
		quest_state_changed.emit(id, State.EMPTY)


func _set_state(quest_id: String, state: int) -> void:
	_quests[quest_id]["state"] = state
	quest_state_changed.emit(quest_id, state)
