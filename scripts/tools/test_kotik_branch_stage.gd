extends Node

## Ветка Котика: три этапа, ошейник, финальный комикс; общие правила веток и лимиты на день:
##   godot --headless --path . res://scenes/tools/test_kotik_branch_stage.tscn

const KOTIK := "res://scenes/actors/npcs/kotik.tscn"
const ENCOUNTER_ITEM := "res://scenes/world/encounter_item.tscn"


func _ready() -> void:
	DaySystem.end_on_failed_spend = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: Array[String] = []
	_reset()

	await _test_stage_1_talk(errors)
	await _test_stage_2_collar(errors)
	await _test_stage_3_give_collar_and_final_comic(errors)
	await _test_branch_rules(errors)
	await _test_kotik_in_library(errors)
	_test_daily_use_limit(errors)

	_reset()
	for e in errors:
		print("  [ERROR] %s" % e)
	if errors.is_empty():
		print("[test_kotik_branch_stage] OK")
	else:
		print("[test_kotik_branch_stage] ПРОВАЛ — ошибок: %d" % errors.size())
	get_tree().quit(errors.size())


func _reset() -> void:
	EnerginkaSystem.reset_progress()
	BranchSystem.reset_progress()
	DaySystem.reset_progress()
	CabinetPool.reroll_sharaga()


func _plan(branch_stage_id: String, errors: Array) -> void:
	if not BranchSystem.invest_energinka(branch_stage_id):
		errors.append("не удалось вложить энергинку в %s" % branch_stage_id)
		return
	if not EnerginkaSystem.spend_energinka(BranchSystem.get_pending_count()):
		errors.append("не удалось потратить энергинку за %s" % branch_stage_id)
	var planned := BranchSystem.confirm_plan()
	if not planned.has(branch_stage_id):
		errors.append("confirm_plan не запланировал %s" % branch_stage_id)


func _talk(npc: EncounterNpc, expected_comic: String, errors: Array) -> void:
	npc._sych_in_range = true
	npc._interact()
	await get_tree().process_frame
	if not ComicDialogueSystem.is_active():
		errors.append("E не открыл комиксный диалог %s" % expected_comic)
		return
	if ComicDialogueSystem._active_comic_dialogue_id != expected_comic:
		errors.append("открылся диалог %s вместо %s" % [ComicDialogueSystem._active_comic_dialogue_id, expected_comic])
	ComicDialogueSystem._active_player._close()
	await get_tree().process_frame
	await get_tree().process_frame


func _test_stage_1_talk(errors: Array) -> void:
	_reset()
	var stages := BranchSystem.get_branch_stage_ids(BranchSystem.BRANCH_KOTIK)
	if stages != [BranchSystem.STAGE_KOTIK_TALK, BranchSystem.STAGE_KOTIK_COLLAR, BranchSystem.STAGE_KOTIK_GIVE_COLLAR]:
		errors.append("у ветки Котика должно быть три этапа по порядку")
	var kotik: EncounterNpc = load(KOTIK).instantiate()
	add_child(kotik)
	await get_tree().process_frame
	if kotik.has_encounter_interaction():
		errors.append("до планирования у Котика нет энкаунтера")
	_plan(BranchSystem.STAGE_KOTIK_TALK, errors)
	if BranchSystem.get_confirmed_description(BranchSystem.STAGE_KOTIK_TALK) != BranchSystem.VORCHANIE_KOTIK_TALK:
		errors.append("наведение на сердечко 1 Котика должно повторять «Котик-Котик-Котик…»")
	for comic in [BranchSystem.COMIC_KOTIK_TALK, BranchSystem.COMIC_KOTIK_COLLAR, BranchSystem.COMIC_KOTIK_FINAL, BranchSystem.COMIC_KOTIK_ANSWER]:
		if ComicDialogueSystem._load_comic_dialogue(comic).get("frames", []).size() != 4:
			errors.append("комиксный диалог %s должен быть из 4 кадров" % comic)
	await _talk(kotik, BranchSystem.COMIC_KOTIK_TALK, errors)
	if BranchSystem.get_state(BranchSystem.STAGE_KOTIK_TALK) != BranchSystem.State.COMPLETED:
		errors.append("после разговора с Котиком этап 1 не COMPLETED")
	if not BranchSystem.can_plan(BranchSystem.STAGE_KOTIK_COLLAR):
		errors.append("после этапа 1 должно открыться второе сердечко Котика")
	kotik.queue_free()
	await get_tree().process_frame
	print("  OK  этап 1: разговор с Котиком")


func _test_stage_2_collar(errors: Array) -> void:
	_reset()
	_plan(BranchSystem.STAGE_KOTIK_TALK, errors)
	BranchSystem.complete_encounter(BranchSystem.ENCOUNTER_KOTIK_TALK)
	var collar: EncounterItem = load(ENCOUNTER_ITEM).instantiate()
	collar.item_id = BranchSystem.ITEM_COLLAR
	collar.hide_when_collected = true
	add_child(collar)
	await get_tree().process_frame
	if collar.interact():
		errors.append("ошейник взялся без активного этапа 2")
	if not collar.visible:
		errors.append("ошейник исчез, хотя его не брали")
	_plan(BranchSystem.STAGE_KOTIK_COLLAR, errors)
	if not BranchSystem.is_item_wanted(BranchSystem.ITEM_COLLAR):
		errors.append("при активном этапе 2 ошейник должен быть нужен")
	if not collar.interact():
		errors.append("ошейник не взялся при активном этапе 2")
	if not BranchSystem.has_item(BranchSystem.ITEM_COLLAR):
		errors.append("после Склада ошейник должен быть на руках (инвентарь-флаг)")
	if collar.visible:
		errors.append("после взятия на Складе ничего полезного нет — ошейник должен исчезнуть")
	if BranchSystem.get_state(BranchSystem.STAGE_KOTIK_COLLAR) != BranchSystem.State.COMPLETED:
		errors.append("после ошейника этап 2 не COMPLETED")
	if not BranchSystem.can_plan(BranchSystem.STAGE_KOTIK_GIVE_COLLAR):
		errors.append("после этапа 2 должно открыться третье сердечко Котика")
	collar.queue_free()
	await get_tree().process_frame
	print("  OK  этап 2: ошейник со Склада")


func _test_stage_3_give_collar_and_final_comic(errors: Array) -> void:
	_reset()
	_plan(BranchSystem.STAGE_KOTIK_TALK, errors)
	BranchSystem.complete_encounter(BranchSystem.ENCOUNTER_KOTIK_TALK)
	_plan(BranchSystem.STAGE_KOTIK_COLLAR, errors)
	BranchSystem.collect_item(BranchSystem.ITEM_COLLAR)
	_plan(BranchSystem.STAGE_KOTIK_GIVE_COLLAR, errors)
	if BranchSystem.get_encounter_objective(BranchSystem.ENCOUNTER_KOTIK_GIVE_COLLAR) != BranchSystem.Objective.DELIVER:
		errors.append("задача энкаунтера этапа 3 — отдать предмет")
	var kotik: EncounterNpc = load(KOTIK).instantiate()
	add_child(kotik)
	await get_tree().process_frame
	if not kotik.has_encounter_interaction():
		errors.append("с ошейником на руках Котик должен принять его")
	await _talk(kotik, BranchSystem.COMIC_KOTIK_COLLAR, errors)
	if BranchSystem.has_item(BranchSystem.ITEM_COLLAR):
		errors.append("после передачи ошейник не должен оставаться на руках")
	if BranchSystem.get_state(BranchSystem.STAGE_KOTIK_GIVE_COLLAR) != BranchSystem.State.COMPLETED:
		errors.append("после передачи ошейника этап 3 не COMPLETED")
	if not BranchSystem.is_branch_completed(BranchSystem.BRANCH_KOTIK):
		errors.append("ветка Котика не завершена")
	await get_tree().process_frame
	await get_tree().process_frame
	if not ComicDialogueSystem.is_active() or ComicDialogueSystem._active_comic_dialogue_id != BranchSystem.COMIC_KOTIK_FINAL:
		errors.append("наградой ветки Котика должен быть финальный комиксный диалог kotik_final")
	if ComicDialogueSystem.is_active():
		ComicDialogueSystem._active_player._close()
		await get_tree().process_frame
		await get_tree().process_frame
	if DaySystem.wake_up_cost != DaySystem.WAKE_UP_COST_DEFAULT:
		errors.append("ветка Котика не должна менять стоимость пробуждения")
	if kotik.has_encounter_interaction():
		errors.append("после завершения ветки у Котика не должно быть энкаунтера")
	kotik.queue_free()
	await get_tree().process_frame
	print("  OK  этап 3: передача ошейника и финальный комикс")


func _test_branch_rules(errors: Array) -> void:
	_reset()
	# Этап 3 без ошейника на руках не засчитывается.
	_plan(BranchSystem.STAGE_KOTIK_TALK, errors)
	BranchSystem.complete_encounter(BranchSystem.ENCOUNTER_KOTIK_TALK)
	_plan(BranchSystem.STAGE_KOTIK_COLLAR, errors)
	BranchSystem.complete_branch_stage(BranchSystem.STAGE_KOTIK_COLLAR)
	_plan(BranchSystem.STAGE_KOTIK_GIVE_COLLAR, errors)
	if BranchSystem.complete_encounter(BranchSystem.ENCOUNTER_KOTIK_GIVE_COLLAR):
		errors.append("нельзя отдать ошейник, которого нет на руках")
	if not BranchSystem.get_npc_interaction(BranchSystem.NPC_KOTIK).is_empty():
		errors.append("без ошейника у Котика нет взаимодействия этапа 3")

	# Вложенная, но не подтверждённая энергинка: PENDING возвращается без следа.
	_reset()
	if not BranchSystem.invest_energinka(BranchSystem.STAGE_KOTIK_TALK):
		errors.append("не удалось вложить энергинку в этап 1 Котика")
	if BranchSystem.get_state(BranchSystem.STAGE_KOTIK_TALK) != BranchSystem.State.PENDING:
		errors.append("после вложения этап должен быть PENDING")
	if BranchSystem.invest_energinka(BranchSystem.STAGE_HISTORIAN_QUESTIONS) and BranchSystem.get_pending_count() != 2:
		errors.append("этапы разных веток планируются параллельно")
	if BranchSystem.has_confirmed_plan():
		errors.append("PENDING не открывает выход из Сычевальни")
	BranchSystem.cancel_all_pending()
	if BranchSystem.has_pending() or BranchSystem.get_state(BranchSystem.STAGE_KOTIK_TALK) != BranchSystem.State.EMPTY:
		errors.append("закрытие доски должно вернуть все PENDING в EMPTY")

	# Активный этап не сгорает с концом дня.
	_plan(BranchSystem.STAGE_KOTIK_TALK, errors)
	DaySystem.day_ended.emit(DaySystem.day_number)
	DaySystem.day_started.emit(DaySystem.day_number + 1)
	if BranchSystem.get_state(BranchSystem.STAGE_KOTIK_TALK) != BranchSystem.State.ACTIVE:
		errors.append("запланированный этап должен пережить конец дня")
	# Новая игра всё сбрасывает.
	BranchSystem.reset_progress()
	DaySystem.reset_progress()
	if BranchSystem.has_confirmed_plan() or BranchSystem.has_item(BranchSystem.ITEM_COLLAR):
		errors.append("reset_progress не очистил ветки")
	if DaySystem.wake_up_cost != DaySystem.WAKE_UP_COST_DEFAULT or DaySystem.day_number != 1:
		errors.append("DaySystem.reset_progress не вернул стоимость пробуждения и день")
	print("  OK  правила: один незакрытый этап, PENDING, этап переживает день")


func _test_kotik_in_library(errors: Array) -> void:
	_reset()
	var choice: Array[StringName] = [&"library", &"classroom"]
	CabinetPool._wing_cabinet_choices[CabinetPool.Wing.SECOND_FLOOR_RIGHT] = choice
	var anchor := Marker3D.new()
	anchor.position = Vector3(0, 1.36, 0)
	add_child(anchor)
	if not CabinetPool.select_cabinet(&"cabinet_slot_9", &"library"):
		errors.append("не удалось вытащить Библиотеку")
	CabinetPool.apply_to_anchor(&"cabinet_slot_9", anchor)
	await get_tree().process_frame
	var kotik := anchor.get_node_or_null(^"Kotik") as EncounterNpc
	if kotik == null or not kotik.visible:
		errors.append("Котик — стабильное содержимое Библиотеки: должен быть там без активного этапа")
	elif kotik.npc_id != BranchSystem.NPC_KOTIK:
		errors.append("у Котика в Библиотеке npc_id должен быть kotik")
	anchor.queue_free()
	await get_tree().process_frame
	print("  OK  Котик всегда в Библиотеке")


func _test_daily_use_limit(errors: Array) -> void:
	DaySystem.reset_progress()
	var id := &"test_source"
	if not DaySystem.can_use_today(id, 1):
		errors.append("свежий день: источник должен быть доступен")
	if not DaySystem.use_today(id, 1):
		errors.append("первое использование за день должно пройти")
	if DaySystem.use_today(id, 1):
		errors.append("лимит 1 раз в день: второе использование должно быть отклонено")
	if DaySystem.uses_today(id) != 1:
		errors.append("счётчик использований должен быть 1")
	if not DaySystem.use_today(&"free_action", 0):
		errors.append("лимит 0 — без ограничения")
	DaySystem._daily_uses.clear()
	if not DaySystem.can_use_today(id, 1):
		errors.append("новый день должен сбросить лимит")
	print("  OK  лимит использования на день")
