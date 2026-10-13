extends Node
## Глобальная система веток. Autoload (см. project.godot → [autoload] BranchSystem).
##
## Цепочка прогрессии: branch → branch_stage → encounter (GDD §6, словарь).
## Две ветки демо (план демо §7–8): Историк (сверху на пробковой доске) и Котик (снизу),
## у каждой ровно три этапа. Сердечко на доске — только UI-представление этапа;
## источник состояния — эта система.
##
## Жизненный цикл этапа ветки (GDD §5):
##   EMPTY      — энергинка не вложена (доступное сердечко, если этап открыт);
##   PENDING    — энергинка вложена, план не подтверждён («ок» не нажат) — термина в словаре нет;
##   ACTIVE     — этап запланирован (confirm_plan) → энкаунтер этапа активирован;
##   COMPLETED  — энкаунтер пройден, этап закрыт.
##
## Правила: в ветке одновременно один незакрытый этап; следующий открывается только после
## закрытия текущего; активный этап не сгорает с концом дня (ничего не сбрасывается в day_started).
##
## Энкаунтер — то, через что выполняется этап. Задача энкаунтера (encounter_objective):
##   TALK    — комиксный диалог с персонажем;
##   COLLECT — собрать N предметов (мировые объекты или реплики персонажей);
##   DELIVER — отдать персонажу предмет из инвентаря-флага.
## Активировать энкаунтер ≠ заспавнить: персонажи и предметы стоят в мире всегда,
## этап лишь делает их «нужными» (см. is_item_wanted / get_npc_interaction).

enum State { EMPTY, PENDING, ACTIVE, COMPLETED }
enum Objective { TALK, COLLECT, DELIVER }

const BRANCH_HISTORIAN := "historian"
const BRANCH_KOTIK := "kotik"
## Порядок веток на пробковой доске сверху вниз (план демо §4).
const BRANCH_ORDER: Array[String] = [BRANCH_HISTORIAN, BRANCH_KOTIK]
const STAGES_PER_BRANCH := 3

## Этапы ветки Историка (план демо §7).
const STAGE_HISTORIAN_QUESTIONS := "historian_questions"  # сердечко 1 — узнать вопросы
const STAGE_HISTORIAN_ANSWERS := "historian_answers"      # сердечко 2 — собрать ответы
const STAGE_HISTORIAN_EXAM := "historian_exam"            # сердечко 3 — сдать Историю
## Этапы ветки Котика (план демо §8).
const STAGE_KOTIK_TALK := "kotik_talk"                    # сердечко 1 — поговорить с Котиком
const STAGE_KOTIK_COLLAR := "kotik_collar"                # сердечко 2 — найти ошейник
const STAGE_KOTIK_GIVE_COLLAR := "kotik_give_collar"      # сердечко 3 — отнести ошейник

## Энкаунтеры: по одному на этап.
const ENCOUNTER_HISTORIAN_QUESTIONS := "historian_questions_talk"
const ENCOUNTER_HISTORIAN_ANSWERS := "historian_answers_collect"
const ENCOUNTER_HISTORIAN_EXAM := "historian_exam_talk"
const ENCOUNTER_KOTIK_TALK := "kotik_talk"
const ENCOUNTER_KOTIK_COLLAR := "kotik_collar_collect"
const ENCOUNTER_KOTIK_GIVE_COLLAR := "kotik_give_collar"

## Предметы энкаунтеров (термина в словаре нет — технические имена).
const ITEM_HISTORIAN_ANSWER_1 := "historian_answer_1"  # надпись на стене в Туалете
const ITEM_HISTORIAN_ANSWER_2 := "historian_answer_2"  # ответ Котика в Библиотеке
const ITEM_HISTORIAN_ANSWER_3 := "historian_answer_3"  # энкаунтер сбора слухов в Актовом зале
const ITEM_COLLAR := "collar"                          # ошейник на Складе

## Персонажи, с которыми ведутся энкаунтеры.
const NPC_HISTORIAN := "historian"
const NPC_KOTIK := "kotik"

## Комиксные диалоги (JSON в res://assets/comic_dialogues/). Кадры — заглушки для потока G.
const COMIC_HISTORIAN_QUESTIONS := "historian_questions"  # Историк даёт три вопроса
const COMIC_HISTORIAN_EXAM := "historian_exam"            # сдача: зачёт и сакральное знание
const COMIC_KOTIK_TALK := "kotik_talk"                    # первый разговор: нужен ошейник
const COMIC_KOTIK_ANSWER := "kotik_answer"                # Котик сообщает ответ 2 (решение §7.5)
const COMIC_KOTIK_COLLAR := "kotik_collar"                # передача ошейника
const COMIC_KOTIK_FINAL := "kotik_final"                  # награда: финальный комикс (решение §7.6)

## Ворчания этапов — после подтверждения и по наведению на сердечко (план демо §7–8).
const VORCHANIE_HISTORIAN_QUESTIONS := "Историк где-то в Шараге."
const VORCHANIE_HISTORIAN_ANSWERS := "Это не Новая история и не Новейшая, это совсем Новая История Жесть, че ее учить. Соберу по кускам - она, блин, на стенах написана и с Восстания десять лет прошло, а все до сих пор его обсуждают... Ну и кто-нибудь наверняка ботал."
const VORCHANIE_HISTORIAN_EXAM := "Пойду сдам, где там Историк сидел?"
const VORCHANIE_KOTIK_TALK := "Котик-Котик-Котик, хочу найти Котика, нужен Котик."
const VORCHANIE_KOTIK_COLLAR := "Господи, как ему пойдет ошейник. Где, блин, взять ошейник..."
const VORCHANIE_KOTIK_GIVE_COLLAR := "Подойду, вытащу его морду из книг и такая: \"Кхе-кхем. У меня дома есть отличный ошейник. Хочешь примерить?\""

## Награда ветки Историка — постоянная прокачка: проснуться за 1 энергинку (план демо §7).
const HISTORIAN_REWARD_WAKE_UP_COST := 1

## Меняется состояние любого этапа ветки (для UI доски).
signal branch_stage_state_changed(branch_stage_id: String, state: int)
## Этап запланирован (подтверждён через «ок»).
signal branch_stage_planned(branch_stage_id: String)
## Этап ветки закрыт.
signal branch_stage_completed(branch_stage_id: String)
## Все этапы ветки закрыты; награда ветки уже применена.
signal branch_completed(branch: String)
## Энкаунтер стал действующим (активный энкаунтер).
signal encounter_activated(encounter_id: String)
## Задача энкаунтера выполнена.
signal encounter_completed(encounter_id: String)
## Предмет энкаунтера получен (ответ, ошейник).
signal item_collected(item_id: String)

var _branches: Dictionary = {}    # branch -> Array[String] stage ids по порядку
var _stages: Dictionary = {}      # stage id -> Dictionary
var _encounters: Dictionary = {}  # encounter id -> Dictionary
var _items: Dictionary = {}       # item id -> true (инвентарь-флаг)
var _rewarded_branches: Dictionary = {}  # branch -> true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_define_branches()


func _define_branches() -> void:
	# --- Ветка Историка ---
	_define_branch_stage(STAGE_HISTORIAN_QUESTIONS, BRANCH_HISTORIAN, 0, "Узнать вопросы", VORCHANIE_HISTORIAN_QUESTIONS)
	_define_talk_encounter(ENCOUNTER_HISTORIAN_QUESTIONS, STAGE_HISTORIAN_QUESTIONS, NPC_HISTORIAN, COMIC_HISTORIAN_QUESTIONS)

	_define_branch_stage(STAGE_HISTORIAN_ANSWERS, BRANCH_HISTORIAN, 1, "Собрать ответы", VORCHANIE_HISTORIAN_ANSWERS)
	_define_collect_encounter(ENCOUNTER_HISTORIAN_ANSWERS, STAGE_HISTORIAN_ANSWERS, {
		ITEM_HISTORIAN_ANSWER_1: {},
		ITEM_HISTORIAN_ANSWER_2: {"npc": NPC_KOTIK, "comic_dialogue": COMIC_KOTIK_ANSWER},
		ITEM_HISTORIAN_ANSWER_3: {},
	})

	_define_branch_stage(STAGE_HISTORIAN_EXAM, BRANCH_HISTORIAN, 2, "Сдать Историю", VORCHANIE_HISTORIAN_EXAM)
	_define_talk_encounter(ENCOUNTER_HISTORIAN_EXAM, STAGE_HISTORIAN_EXAM, NPC_HISTORIAN, COMIC_HISTORIAN_EXAM)

	# --- Ветка Котика ---
	_define_branch_stage(STAGE_KOTIK_TALK, BRANCH_KOTIK, 0, "Поговорить с Котиком", VORCHANIE_KOTIK_TALK)
	_define_talk_encounter(ENCOUNTER_KOTIK_TALK, STAGE_KOTIK_TALK, NPC_KOTIK, COMIC_KOTIK_TALK)

	_define_branch_stage(STAGE_KOTIK_COLLAR, BRANCH_KOTIK, 1, "Найти ошейник", VORCHANIE_KOTIK_COLLAR)
	_define_collect_encounter(ENCOUNTER_KOTIK_COLLAR, STAGE_KOTIK_COLLAR, {ITEM_COLLAR: {}})

	_define_branch_stage(STAGE_KOTIK_GIVE_COLLAR, BRANCH_KOTIK, 2, "Отнести ошейник", VORCHANIE_KOTIK_GIVE_COLLAR)
	_define_deliver_encounter(ENCOUNTER_KOTIK_GIVE_COLLAR, STAGE_KOTIK_GIVE_COLLAR, NPC_KOTIK, ITEM_COLLAR, COMIC_KOTIK_COLLAR)


func _define_branch_stage(id: String, branch: String, index: int, title: String, vorchanie: String) -> void:
	if not _branches.has(branch):
		_branches[branch] = [] as Array[String]
	var ids: Array[String] = _branches[branch]
	while ids.size() <= index:
		ids.append("")
	ids[index] = id
	_stages[id] = {
		"id": id,
		"branch": branch,
		"index": index,
		"title": title,
		"vorchanie": vorchanie,
		"encounter": "",
		"state": State.EMPTY,
	}


func _define_talk_encounter(id: String, stage_id: String, npc: String, comic_dialogue_id: String) -> void:
	_define_encounter(id, stage_id, Objective.TALK, {"npc": npc, "comic_dialogue": comic_dialogue_id})


## items: item_id -> {"npc": кто сообщает (пусто — мировой объект), "comic_dialogue": диалог при получении}.
func _define_collect_encounter(id: String, stage_id: String, items: Dictionary) -> void:
	_define_encounter(id, stage_id, Objective.COLLECT, {"items": items})


func _define_deliver_encounter(id: String, stage_id: String, npc: String, item_id: String, comic_dialogue_id: String) -> void:
	_define_encounter(id, stage_id, Objective.DELIVER, {"npc": npc, "item": item_id, "comic_dialogue": comic_dialogue_id})


func _define_encounter(id: String, stage_id: String, objective: int, extra: Dictionary) -> void:
	var encounter := {
		"id": id,
		"stage": stage_id,
		"objective": objective,
		"npc": "",
		"comic_dialogue": "",
		"items": {},
		"item": "",
		"collected": {},
	}
	encounter.merge(extra, true)
	_encounters[id] = encounter
	_stages[stage_id]["encounter"] = id


# ---------------------------------------------------------------------------
# Ветки и этапы
# ---------------------------------------------------------------------------

func get_branches() -> Array[String]:
	return BRANCH_ORDER.duplicate()


func get_branch_stage_ids(branch: String) -> Array[String]:
	var ids: Array[String] = _branches.get(branch, [] as Array[String])
	return ids.duplicate()


func get_branch_stage_id(branch: String, index: int) -> String:
	var ids: Array[String] = _branches.get(branch, [] as Array[String])
	if index < 0 or index >= ids.size():
		return ""
	return ids[index]


func has_branch_stage(branch_stage_id: String) -> bool:
	return _stages.has(branch_stage_id)


func get_state(branch_stage_id: String) -> int:
	if not _stages.has(branch_stage_id):
		return State.EMPTY
	return _stages[branch_stage_id]["state"]


func get_title(branch_stage_id: String) -> String:
	if not _stages.has(branch_stage_id):
		return ""
	return _stages[branch_stage_id]["title"]


func get_branch(branch_stage_id: String) -> String:
	if not _stages.has(branch_stage_id):
		return ""
	return _stages[branch_stage_id]["branch"]


func get_stage_index(branch_stage_id: String) -> int:
	if not _stages.has(branch_stage_id):
		return -1
	return _stages[branch_stage_id]["index"]


## Ворчание этапа: звучит после подтверждения и повторяется по наведению на сердечко.
func get_vorchanie(branch_stage_id: String) -> String:
	if not _stages.has(branch_stage_id):
		return ""
	return _stages[branch_stage_id]["vorchanie"]


## Этап открыт для планирования: первый этап ветки — всегда, остальные — после закрытия предыдущего.
func is_unlocked(branch_stage_id: String) -> bool:
	if not _stages.has(branch_stage_id):
		return false
	var stage: Dictionary = _stages[branch_stage_id]
	if int(stage["index"]) == 0:
		return true
	var previous := get_branch_stage_id(stage["branch"], int(stage["index"]) - 1)
	return previous != "" and get_state(previous) == State.COMPLETED


## Доступное сердечко: открыт, пуст, и в ветке нет другого незакрытого этапа.
func can_plan(branch_stage_id: String) -> bool:
	if not _stages.has(branch_stage_id):
		return false
	if get_state(branch_stage_id) != State.EMPTY or not is_unlocked(branch_stage_id):
		return false
	return get_open_branch_stage(get_branch(branch_stage_id)) == ""


## Незакрытый этап ветки (PENDING или ACTIVE), иначе "".
func get_open_branch_stage(branch: String) -> String:
	for id in get_branch_stage_ids(branch):
		var state := get_state(id)
		if state == State.PENDING or state == State.ACTIVE:
			return id
	return ""


## Активный (запланированный, не закрытый) этап ветки, иначе "".
func get_active_branch_stage(branch: String) -> String:
	for id in get_branch_stage_ids(branch):
		if get_state(id) == State.ACTIVE:
			return id
	return ""


func is_branch_completed(branch: String) -> bool:
	var ids := get_branch_stage_ids(branch)
	if ids.is_empty():
		return false
	for id in ids:
		if get_state(id) != State.COMPLETED:
			return false
	return true


## Текст для наведения на сердечко после «ок». Пока план не подтверждён, строки нет.
func get_confirmed_description(branch_stage_id: String) -> String:
	var state := get_state(branch_stage_id)
	if state != State.ACTIVE and state != State.COMPLETED:
		return ""
	return get_vorchanie(branch_stage_id)


## Вложить энергинку: EMPTY → PENDING (энергинка перетащена, план не подтверждён).
func invest_energinka(branch_stage_id: String) -> bool:
	if not can_plan(branch_stage_id):
		return false
	_set_state(branch_stage_id, State.PENDING)
	return true


## PENDING → EMPTY (вернули энергинку до подтверждения).
func cancel_pending(branch_stage_id: String) -> bool:
	if get_state(branch_stage_id) != State.PENDING:
		return false
	_set_state(branch_stage_id, State.EMPTY)
	return true


func cancel_all_pending() -> void:
	for id in _stages:
		cancel_pending(id)


func has_pending() -> bool:
	return get_pending_count() > 0


func get_pending_count() -> int:
	var count := 0
	for id in _stages:
		if _stages[id]["state"] == State.PENDING:
			count += 1
	return count


## Подтвердить план («ок»): все PENDING → ACTIVE, их энкаунтеры активируются.
## Энергинки списывает вызывающий (доска) до вызова. Возвращает список запланированных id.
func confirm_plan() -> Array[String]:
	var planned: Array[String] = []
	for branch in BRANCH_ORDER:
		for id in get_branch_stage_ids(branch):
			if get_state(id) == State.PENDING:
				_set_state(id, State.ACTIVE)
				planned.append(id)
	for id in planned:
		branch_stage_planned.emit(id)
		var encounter_id: String = _stages[id]["encounter"]
		if encounter_id != "":
			encounter_activated.emit(encounter_id)
	return planned


## Хотя бы один этап уже запланирован или закрыт — открывает выход из Сычевальни (план демо §4).
func has_confirmed_plan() -> bool:
	for id in _stages:
		if int(_stages[id]["state"]) >= State.ACTIVE:
			return true
	return false


## Закрыть этап ветки. Обычно вызывается из complete_encounter.
func complete_branch_stage(branch_stage_id: String) -> bool:
	if not _stages.has(branch_stage_id) or get_state(branch_stage_id) == State.COMPLETED:
		return false
	_set_state(branch_stage_id, State.COMPLETED)
	branch_stage_completed.emit(branch_stage_id)
	var branch: String = _stages[branch_stage_id]["branch"]
	if is_branch_completed(branch):
		_complete_branch(branch)
	return true


func _complete_branch(branch: String) -> void:
	if _rewarded_branches.has(branch):
		return
	_rewarded_branches[branch] = true
	_apply_branch_reward(branch)
	branch_completed.emit(branch)


## Награда ветки (термина в словаре нет): Историк — «проснуться за 1»; Котик — финальный комикс.
func _apply_branch_reward(branch: String) -> void:
	match branch:
		BRANCH_HISTORIAN:
			DaySystem.set_wake_up_cost(HISTORIAN_REWARD_WAKE_UP_COST)
		BRANCH_KOTIK:
			# Отложенно: ветка закрывается внутри comic_dialogue_finished предыдущего диалога.
			_play_comic_dialogue.call_deferred(COMIC_KOTIK_FINAL)


func has_branch_reward(branch: String) -> bool:
	return _rewarded_branches.has(branch)


func _play_comic_dialogue(comic_dialogue_id: String) -> void:
	if ComicDialogueSystem.is_active():
		await ComicDialogueSystem.comic_dialogue_finished
	ComicDialogueSystem.start_comic_dialogue(comic_dialogue_id)


# ---------------------------------------------------------------------------
# Энкаунтеры
# ---------------------------------------------------------------------------

func get_encounter_id(branch_stage_id: String) -> String:
	if not _stages.has(branch_stage_id):
		return ""
	return _stages[branch_stage_id]["encounter"]


func get_encounter_objective(encounter_id: String) -> int:
	if not _encounters.has(encounter_id):
		return -1
	return _encounters[encounter_id]["objective"]


func get_encounter_comic_dialogue(encounter_id: String) -> String:
	if not _encounters.has(encounter_id):
		return ""
	return _encounters[encounter_id]["comic_dialogue"]


## Активный энкаунтер: его этап запланирован и ещё не закрыт.
func is_encounter_active(encounter_id: String) -> bool:
	if not _encounters.has(encounter_id):
		return false
	return get_state(_encounters[encounter_id]["stage"]) == State.ACTIVE


func get_active_encounters() -> Array[String]:
	var out: Array[String] = []
	for branch in BRANCH_ORDER:
		var stage := get_active_branch_stage(branch)
		if stage != "":
			out.append(get_encounter_id(stage))
	return out


## Сколько предметов энкаунтера уже собрано / сколько нужно.
func get_collected_count(encounter_id: String) -> int:
	if not _encounters.has(encounter_id):
		return 0
	return _encounters[encounter_id]["collected"].size()


func get_required_count(encounter_id: String) -> int:
	if not _encounters.has(encounter_id):
		return 0
	return _encounters[encounter_id]["items"].size()


## Пройти энкаунтер: задача выполнена → этап закрывается.
func complete_encounter(encounter_id: String) -> bool:
	if not is_encounter_active(encounter_id):
		return false
	var encounter: Dictionary = _encounters[encounter_id]
	if int(encounter["objective"]) == Objective.DELIVER:
		var item: String = encounter["item"]
		if not has_item(item):
			return false
		_items.erase(item)
	encounter_completed.emit(encounter_id)
	complete_branch_stage(encounter["stage"])
	return true


## Что персонаж npc_id должен сделать по E прямо сейчас. Пустой словарь — энкаунтера нет
## (персонаж отвечает своим пулом реплик). Приоритет: собственный этап ветки персонажа,
## затем предметы для других веток (Котик сообщает ответ 2 Историка).
## Ключи: encounter, comic_dialogue, item ("" для TALK/DELIVER).
func get_npc_interaction(npc_id: String) -> Dictionary:
	for encounter_id in get_active_encounters():
		var encounter: Dictionary = _encounters[encounter_id]
		if encounter["npc"] != npc_id:
			continue
		match int(encounter["objective"]):
			Objective.TALK:
				return {"encounter": encounter_id, "comic_dialogue": encounter["comic_dialogue"], "item": ""}
			Objective.DELIVER:
				if has_item(encounter["item"]):
					return {"encounter": encounter_id, "comic_dialogue": encounter["comic_dialogue"], "item": ""}
	for encounter_id in get_active_encounters():
		var encounter: Dictionary = _encounters[encounter_id]
		if int(encounter["objective"]) != Objective.COLLECT:
			continue
		var items: Dictionary = encounter["items"]
		for item_id in items:
			if encounter["collected"].has(item_id):
				continue
			var source: Dictionary = items[item_id]
			if source.get("npc", "") == npc_id:
				return {"encounter": encounter_id, "comic_dialogue": source.get("comic_dialogue", ""), "item": item_id}
	return {}


## Завершить взаимодействие из get_npc_interaction (после комиксного диалога).
func resolve_npc_interaction(interaction: Dictionary) -> bool:
	if interaction.is_empty():
		return false
	var item: String = interaction.get("item", "")
	if item != "":
		return collect_item(item)
	return complete_encounter(interaction.get("encounter", ""))


# ---------------------------------------------------------------------------
# Предметы энкаунтеров (ответы Историка, ошейник)
# ---------------------------------------------------------------------------

## Предмет нужен активному энкаунтеру сбора и ещё не получен.
func is_item_wanted(item_id: String) -> bool:
	return _find_collect_encounter_for(item_id) != ""


## Предмет уже получен (лежит в инвентаре-флаге или зачтён энкаунтеру).
func is_item_collected(item_id: String) -> bool:
	if _items.has(item_id):
		return true
	for encounter_id in _encounters:
		if _encounters[encounter_id]["collected"].has(item_id):
			return true
	return false


## Предмет сейчас на руках (ошейник до передачи Котику).
func has_item(item_id: String) -> bool:
	return _items.has(item_id)


## Получить предмет. Возвращает false, если он никому сейчас не нужен или уже получен.
func collect_item(item_id: String) -> bool:
	var encounter_id := _find_collect_encounter_for(item_id)
	if encounter_id == "":
		return false
	var encounter: Dictionary = _encounters[encounter_id]
	encounter["collected"][item_id] = true
	_items[item_id] = true
	item_collected.emit(item_id)
	if encounter["collected"].size() >= encounter["items"].size():
		complete_encounter(encounter_id)
	return true


func _find_collect_encounter_for(item_id: String) -> String:
	for encounter_id in get_active_encounters():
		var encounter: Dictionary = _encounters[encounter_id]
		if int(encounter["objective"]) != Objective.COLLECT:
			continue
		if encounter["items"].has(item_id) and not encounter["collected"].has(item_id):
			return encounter_id
	return ""


# ---------------------------------------------------------------------------

func reset_progress() -> void:
	_branches.clear()
	_stages.clear()
	_encounters.clear()
	_items.clear()
	_rewarded_branches.clear()
	_define_branches()
	for id in _stages:
		branch_stage_state_changed.emit(id, State.EMPTY)


func _set_state(branch_stage_id: String, state: int) -> void:
	_stages[branch_stage_id]["state"] = state
	branch_stage_state_changed.emit(branch_stage_id, state)
