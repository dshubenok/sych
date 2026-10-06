extends Node
## Глобальная система веток и их этапов. Autoload (см. project.godot → [autoload] BranchSystem).
##
## Цепочка прогрессии: branch → branch_stage → encounter.
## Каждый этап ветки привязан к ветке (kotik / demonolog) и к слоту сердечка на пробковой доске.
## Нижний ряд доски — ветка Демонолога (пока портрет и сердца Лисика).
## Жизненный цикл состояния этапа ветки:
##   EMPTY      — ничего не перетаскивали;
##   PENDING    — энергинка вложена в сердечко, но план не подтверждён (не нажато «Принять»);
##   ACTIVE     — этап запланирован (нажато «Принять») → активирует энкаунтер в мире;
##   COMPLETED  — этап ветки закрыт.

enum State { EMPTY, PENDING, ACTIVE, COMPLETED }

const BRANCH_KOTIK := "kotik"
const BRANCH_LISIK := "lisik"
const BRANCH_DEMONOLOG := BRANCH_LISIK

const BRANCH_STAGE_FIND_KOTIK := "find_kotik"
const BRANCH_STAGE_FIND_HISTORIAN := "find_historian"
const BRANCH_STAGE_DEMONOLOG_2 := "demonologist_2"

const HISTORIAN_CORKBOARD_MESSAGE := "До меня дошел слух, что наш жуткий Демонолог был когда-то студентом преподавателя Истории. Проверим из первых рук."
const COMPLETE_BANNER_TEXT := "Ура! Этап ветки закрыт!"
const COMPLETE_BANNER_SECONDS := 2.4
const COMPLETE_BANNER_LAYER := 205

## Меняется состояние любого этапа ветки (для обновления UI доски).
signal branch_stage_state_changed(branch_stage_id: String, state: int)
## Этап ветки запланирован (подтверждён через «Принять») — здесь подвешиваются игровые события.
signal branch_stage_planned(branch_stage_id: String)
## Этап ветки закрыт.
signal branch_stage_completed(branch_stage_id: String)

var _branch_stages: Dictionary = {}
var _slot_to_branch_stage: Dictionary = {}
var _complete_banner: CanvasLayer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_define_branch_stages()


func _define_branch_stages() -> void:
	_define_branch_stage(BRANCH_STAGE_FIND_KOTIK, BRANCH_KOTIK, 0, "Найти Котика и поговорить")
	_define_branch_stage(
		BRANCH_STAGE_FIND_HISTORIAN,
		BRANCH_DEMONOLOG,
		4,
		"Поговорить с преподавателем Истории",
		"",
		HISTORIAN_CORKBOARD_MESSAGE,
	)
	_define_branch_stage(
		BRANCH_STAGE_DEMONOLOG_2,
		BRANCH_DEMONOLOG,
		5,
		"Следующий шаг ветки Демонолога",
		BRANCH_STAGE_FIND_HISTORIAN,
	)


func _define_branch_stage(
	id: String,
	branch: String,
	slot_index: int,
	title: String,
	requires: String = "",
	corkboard_message: String = "",
) -> void:
	_branch_stages[id] = {
		"id": id,
		"branch": branch,
		"slot": slot_index,
		"title": title,
		"requires": requires,
		"corkboard_message": corkboard_message,
		"state": State.EMPTY,
	}
	_slot_to_branch_stage[slot_index] = id


func has_branch_stage_for_slot(slot_index: int) -> bool:
	return _slot_to_branch_stage.has(slot_index)


func get_branch_stage_id_for_slot(slot_index: int) -> String:
	return _slot_to_branch_stage.get(slot_index, "")


func get_state(branch_stage_id: String) -> int:
	if not _branch_stages.has(branch_stage_id):
		return State.EMPTY
	return _branch_stages[branch_stage_id]["state"]


func get_state_for_slot(slot_index: int) -> int:
	var id := get_branch_stage_id_for_slot(slot_index)
	if id == "":
		return State.EMPTY
	return get_state(id)


func get_title(branch_stage_id: String) -> String:
	if not _branch_stages.has(branch_stage_id):
		return ""
	return _branch_stages[branch_stage_id]["title"]


func get_branch(branch_stage_id: String) -> String:
	if not _branch_stages.has(branch_stage_id):
		return ""
	return _branch_stages[branch_stage_id]["branch"]


func is_unlocked(branch_stage_id: String) -> bool:
	if not _branch_stages.has(branch_stage_id):
		return false
	var req: String = _branch_stages[branch_stage_id].get("requires", "")
	if req == "":
		return true
	return get_state(req) == State.COMPLETED


func is_slot_unlocked(slot_index: int) -> bool:
	var id := get_branch_stage_id_for_slot(slot_index)
	if id == "":
		return false
	return is_unlocked(id)


func can_accept_slot(slot_index: int) -> bool:
	var id := get_branch_stage_id_for_slot(slot_index)
	if id == "":
		return false
	return get_state(id) == State.EMPTY and is_unlocked(id)


## Текст, который можно перечитать наведением на сердечко после «ок».
## Пока план не подтверждён, строки нет.
func get_confirmed_description(slot_index: int) -> String:
	var id := get_branch_stage_id_for_slot(slot_index)
	if id == "":
		return ""
	var state := get_state(id)
	if state != State.ACTIVE and state != State.COMPLETED:
		return ""
	var msg: String = _branch_stages[id].get("corkboard_message", "")
	if msg != "":
		return msg
	return get_title(id)


## Ворчание активного этапа ветки. Его говорит VorchanieSystem снизу экрана, не подпись на доске.
func get_corkboard_message() -> String:
	for id in _branch_stages:
		var stage: Dictionary = _branch_stages[id]
		if int(stage["state"]) < State.ACTIVE:
			continue
		var msg: String = stage.get("corkboard_message", "")
		if msg != "":
			return msg
	return ""


## Вложить энергинку: EMPTY → PENDING (энергинка перетащена, но план не подтверждён).
func invest_energinka(branch_stage_id: String) -> bool:
	if not _branch_stages.has(branch_stage_id) or _branch_stages[branch_stage_id]["state"] != State.EMPTY:
		return false
	if not is_unlocked(branch_stage_id):
		return false
	_set_state(branch_stage_id, State.PENDING)
	return true


## PENDING → EMPTY (вернули энергинку до подтверждения).
func cancel_pending(branch_stage_id: String) -> bool:
	if not _branch_stages.has(branch_stage_id) or _branch_stages[branch_stage_id]["state"] != State.PENDING:
		return false
	_set_state(branch_stage_id, State.EMPTY)
	return true


func has_pending() -> bool:
	for id in _branch_stages:
		if _branch_stages[id]["state"] == State.PENDING:
			return true
	return false


func get_pending_count() -> int:
	var count := 0
	for id in _branch_stages:
		if _branch_stages[id]["state"] == State.PENDING:
			count += 1
	return count


## Подтвердить план («Принять»): все PENDING → ACTIVE. Возвращает список запланированных id.
func confirm_plan() -> Array:
	var planned: Array = []
	for id in _branch_stages:
		if _branch_stages[id]["state"] == State.PENDING:
			_set_state(id, State.ACTIVE)
			planned.append(id)
	for id in planned:
		branch_stage_planned.emit(id)
	return planned


## Закрыть этап ветки: любое не завершённое состояние → COMPLETED.
func complete_branch_stage(branch_stage_id: String) -> bool:
	if not _branch_stages.has(branch_stage_id) or _branch_stages[branch_stage_id]["state"] == State.COMPLETED:
		return false
	_set_state(branch_stage_id, State.COMPLETED)
	branch_stage_completed.emit(branch_stage_id)
	show_branch_stage_complete_banner()
	return true


func show_branch_stage_complete_banner() -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	if is_instance_valid(_complete_banner):
		_complete_banner.queue_free()
	var layer := CanvasLayer.new()
	layer.name = "BranchStageCompleteBanner"
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
	for id in _branch_stages:
		if int(_branch_stages[id]["state"]) >= State.ACTIVE:
			return true
	return false


func reset_progress() -> void:
	if is_instance_valid(_complete_banner):
		_complete_banner.queue_free()
	_complete_banner = null
	_branch_stages.clear()
	_slot_to_branch_stage.clear()
	_define_branch_stages()
	for id in _branch_stages:
		branch_stage_state_changed.emit(id, State.EMPTY)


func _set_state(branch_stage_id: String, state: int) -> void:
	_branch_stages[branch_stage_id]["state"] = state
	branch_stage_state_changed.emit(branch_stage_id, state)
