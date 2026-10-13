extends Node

## Ветка Историка: три этапа, энкаунтеры, награда «проснуться за 1» (план демо §7):
##   godot --headless --path . res://scenes/tools/test_historian_branch_stage.tscn

const HISTORIAN := "res://scenes/actors/npcs/historian.tscn"
const KOTIK := "res://scenes/actors/npcs/kotik.tscn"
const ENCOUNTER_ITEM := "res://scenes/world/encounter_item.tscn"
const CORKBOARD_UI := "res://scenes/ui/corkboard_ui.tscn"


func _ready() -> void:
	DaySystem.end_on_failed_spend = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: Array[String] = []
	_reset()

	await _test_structure_and_corkboard(errors)
	await _test_stage_1_questions(errors)
	await _test_stage_2_answers(errors)
	await _test_stage_3_exam_and_reward(errors)
	await _test_spawn_in_historian_cabinet(errors)
	await _test_scale(errors)

	_reset()
	for e in errors:
		print("  [ERROR] %s" % e)
	if errors.is_empty():
		print("[test_historian_branch_stage] OK")
	else:
		print("[test_historian_branch_stage] ПРОВАЛ — ошибок: %d" % errors.size())
	get_tree().quit(errors.size())


func _reset() -> void:
	EnerginkaSystem.reset_progress()
	BranchSystem.reset_progress()
	DaySystem.reset_progress()
	CabinetPool.reroll_sharaga()


## Запланировать этап так, как это делает доска: вложить, списать энергинку, «ок».
func _plan(branch_stage_id: String, errors: Array) -> void:
	if not BranchSystem.invest_energinka(branch_stage_id):
		errors.append("не удалось вложить энергинку в %s" % branch_stage_id)
		return
	if not EnerginkaSystem.spend_energinka(BranchSystem.get_pending_count()):
		errors.append("не удалось потратить энергинку за %s" % branch_stage_id)
	var planned := BranchSystem.confirm_plan()
	if not planned.has(branch_stage_id):
		errors.append("confirm_plan не запланировал %s" % branch_stage_id)


## Поговорить с персонажем по E и закрыть комиксный диалог кнопкой «Назад»/закрытием.
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


func _test_structure_and_corkboard(errors: Array) -> void:
	_reset()
	var branches := BranchSystem.get_branches()
	if branches != [BranchSystem.BRANCH_HISTORIAN, BranchSystem.BRANCH_KOTIK]:
		errors.append("порядок веток на доске: Историк сверху, Котик снизу")
	var stages := BranchSystem.get_branch_stage_ids(BranchSystem.BRANCH_HISTORIAN)
	if stages != [BranchSystem.STAGE_HISTORIAN_QUESTIONS, BranchSystem.STAGE_HISTORIAN_ANSWERS, BranchSystem.STAGE_HISTORIAN_EXAM]:
		errors.append("у ветки Историка должно быть три этапа по порядку")
	if not BranchSystem.can_plan(BranchSystem.STAGE_HISTORIAN_QUESTIONS):
		errors.append("первое сердечко Историка должно быть доступно с утра")
	if BranchSystem.can_plan(BranchSystem.STAGE_HISTORIAN_ANSWERS) or BranchSystem.can_plan(BranchSystem.STAGE_HISTORIAN_EXAM):
		errors.append("второе и третье сердечки закрыты, пока первый этап не пройден")
	if BranchSystem.get_confirmed_description(BranchSystem.STAGE_HISTORIAN_QUESTIONS) != "":
		errors.append("до «ок» наведение на сердечко ничего не говорит")

	_plan(BranchSystem.STAGE_HISTORIAN_QUESTIONS, errors)
	if BranchSystem.get_state(BranchSystem.STAGE_HISTORIAN_QUESTIONS) != BranchSystem.State.ACTIVE:
		errors.append("после «ок» этап 1 Историка не ACTIVE")
	if not BranchSystem.is_encounter_active(BranchSystem.ENCOUNTER_HISTORIAN_QUESTIONS):
		errors.append("после «ок» энкаунтер этапа 1 не активен")
	if BranchSystem.get_confirmed_description(BranchSystem.STAGE_HISTORIAN_QUESTIONS) != BranchSystem.VORCHANIE_HISTORIAN_QUESTIONS:
		errors.append("наведение на сердечко 1 должно повторять «Историк где-то в Шараге.»")
	if BranchSystem.can_plan(BranchSystem.STAGE_HISTORIAN_ANSWERS):
		errors.append("нельзя запланировать этап 2, пока этап 1 не закрыт (один незакрытый этап на ветку)")
	if not BranchSystem.can_plan(BranchSystem.STAGE_KOTIK_TALK):
		errors.append("ветку Котика можно планировать параллельно с Историком")
	if not BranchSystem.has_confirmed_plan():
		errors.append("после первого запланированного этапа выход должен открыться")
	if EnerginkaSystem.energinka_pool != 4:
		errors.append("после планирования этапа пул энергинок должен быть 4, было %d" % EnerginkaSystem.energinka_pool)

	var ui: CorkboardUi = load(CORKBOARD_UI).instantiate()
	add_child(ui)
	await get_tree().process_frame
	await get_tree().process_frame
	var title := ui.get_node("Root/BoardFrame/BoardContent/Title") as Label
	if not title.visible or title.text != "Мои хитрые планы":
		errors.append("заголовок доски должен быть «Мои хитрые планы»")
	var hist_hearts := ui.get_node("Root/BoardFrame/BoardContent/HistorianHearts") as HBoxContainer
	var kotik_hearts := ui.get_node("Root/BoardFrame/BoardContent/KotikHearts") as HBoxContainer
	if hist_hearts.get_child_count() != 3 or kotik_hearts.get_child_count() != 3:
		errors.append("на доске по три сердечка на ветку, было %d/%d" % [hist_hearts.get_child_count(), kotik_hearts.get_child_count()])
	else:
		var first := hist_hearts.get_child(0) as CorkboardHeart
		if first.branch_stage_id != BranchSystem.STAGE_HISTORIAN_QUESTIONS:
			errors.append("первое сердечко Историка не привязано к этапу 1")
	var message := ui.get_node("Root/BoardFrame/BoardContent/Message") as Label
	if message.visible and message.text != "":
		errors.append("ворчание этапа висит на доске, а должно быть только нижним ворчанием")
	ui.queue_free()
	await get_tree().process_frame
	print("  OK  структура: 2 ветки × 3 этапа, доска «Мои хитрые планы»")


func _test_stage_1_questions(errors: Array) -> void:
	_reset()
	var npc: EncounterNpc = load(HISTORIAN).instantiate()
	add_child(npc)
	await get_tree().process_frame
	if npc.has_encounter_interaction():
		errors.append("до планирования у Историка не должно быть энкаунтера (только пул реплик)")
	npc._sych_in_range = true
	npc._interact()
	await get_tree().process_frame
	if ComicDialogueSystem.is_active():
		errors.append("без активного этапа Историк не должен открывать комиксный диалог")
		ComicDialogueSystem._active_player._close()
		await get_tree().process_frame
	var line := npc.get_node_or_null(^"Line") as Label3D
	if line == null or not line.visible or not npc.idle_lines.has(line.text):
		errors.append("без энкаунтера Историк должен сказать реплику из пула («Готовьтесь, Сыч…»)")
	npc._line_active = false
	if line:
		line.visible = false

	_plan(BranchSystem.STAGE_HISTORIAN_QUESTIONS, errors)
	if not npc.has_encounter_interaction():
		errors.append("после планирования у Историка должен появиться энкаунтер «узнать вопросы»")
	var data: Dictionary = ComicDialogueSystem._load_comic_dialogue(BranchSystem.COMIC_HISTORIAN_QUESTIONS)
	if data.get("frames", []).size() != 4:
		errors.append("комиксный диалог «вопросы Историка» должен быть из 4 кадров")
	await _talk(npc, BranchSystem.COMIC_HISTORIAN_QUESTIONS, errors)
	if BranchSystem.get_state(BranchSystem.STAGE_HISTORIAN_QUESTIONS) != BranchSystem.State.COMPLETED:
		errors.append("после комиксного диалога этап 1 не COMPLETED")
	if not BranchSystem.can_plan(BranchSystem.STAGE_HISTORIAN_ANSWERS):
		errors.append("после этапа 1 должно открыться второе сердечко")
	if get_tree().root.get_node_or_null(^"BranchStageCompleteBanner") != null:
		errors.append("экрана «Ура!» в документах нет — закрытие этапа без баннера")
	if EnerginkaSystem.max_energinka != 5:
		errors.append("этап Историка не должен менять максимум энергинок")
	npc._sych_in_range = true
	npc._interact()
	await get_tree().process_frame
	if ComicDialogueSystem.is_active():
		errors.append("после закрытия этапа 1 Историк снова открыл диалог вопросов")
		ComicDialogueSystem._active_player._close()
		await get_tree().process_frame
	npc.queue_free()
	await get_tree().process_frame
	print("  OK  этап 1: комиксный диалог «вопросы», сердечко 2 открылось")


func _test_stage_2_answers(errors: Array) -> void:
	_reset()
	_plan(BranchSystem.STAGE_HISTORIAN_QUESTIONS, errors)
	BranchSystem.complete_encounter(BranchSystem.ENCOUNTER_HISTORIAN_QUESTIONS)

	var wall: EncounterItem = load(ENCOUNTER_ITEM).instantiate()
	wall.item_id = BranchSystem.ITEM_HISTORIAN_ANSWER_1
	add_child(wall)
	var rumors: EncounterItem = load(ENCOUNTER_ITEM).instantiate()
	rumors.item_id = BranchSystem.ITEM_HISTORIAN_ANSWER_3
	add_child(rumors)
	var kotik: EncounterNpc = load(KOTIK).instantiate()
	add_child(kotik)
	await get_tree().process_frame

	if BranchSystem.is_item_wanted(BranchSystem.ITEM_HISTORIAN_ANSWER_1):
		errors.append("до планирования этапа 2 надпись на стене никому не нужна")
	if wall.interact():
		errors.append("надпись на стене зачлась без активного этапа 2")
	if kotik.has_encounter_interaction():
		errors.append("Котик не должен давать ответ 2, пока этап 2 Историка не активен")

	_plan(BranchSystem.STAGE_HISTORIAN_ANSWERS, errors)
	var encounter := BranchSystem.ENCOUNTER_HISTORIAN_ANSWERS
	if BranchSystem.get_encounter_objective(encounter) != BranchSystem.Objective.COLLECT:
		errors.append("задача энкаунтера этапа 2 — собрать предметы")
	if BranchSystem.get_required_count(encounter) != 3:
		errors.append("для этапа 2 нужно три ответа")
	if not wall.interact():
		errors.append("надпись в Туалете не зачлась как ответ 1")
	if wall.interact():
		errors.append("ответ 1 зачёлся дважды")
	if BranchSystem.get_collected_count(encounter) != 1:
		errors.append("после Туалета собран должен быть 1 ответ")
	if BranchSystem.get_state(BranchSystem.STAGE_HISTORIAN_ANSWERS) != BranchSystem.State.ACTIVE:
		errors.append("этап 2 закрылся раньше, чем собраны все ответы")

	if not kotik.has_encounter_interaction():
		errors.append("при активном этапе 2 Котик должен сообщить ответ 2")
	await _talk(kotik, BranchSystem.COMIC_KOTIK_ANSWER, errors)
	if not BranchSystem.is_item_collected(BranchSystem.ITEM_HISTORIAN_ANSWER_2):
		errors.append("после комикса с Котиком ответ 2 не зачтён")
	if kotik.has_encounter_interaction():
		errors.append("Котик сообщает ответ 2 повторно")

	if not rumors.interact():
		errors.append("энкаунтер сбора слухов не дал ответ 3")
	if BranchSystem.get_state(BranchSystem.STAGE_HISTORIAN_ANSWERS) != BranchSystem.State.COMPLETED:
		errors.append("после трёх ответов этап 2 не COMPLETED")
	if not BranchSystem.can_plan(BranchSystem.STAGE_HISTORIAN_EXAM):
		errors.append("после этапа 2 должно открыться третье сердечко")
	wall.queue_free()
	rumors.queue_free()
	kotik.queue_free()
	await get_tree().process_frame
	print("  OK  этап 2: три ответа (Туалет, Котик, слухи)")


func _test_stage_3_exam_and_reward(errors: Array) -> void:
	_reset()
	_plan(BranchSystem.STAGE_HISTORIAN_QUESTIONS, errors)
	BranchSystem.complete_encounter(BranchSystem.ENCOUNTER_HISTORIAN_QUESTIONS)
	_plan(BranchSystem.STAGE_HISTORIAN_ANSWERS, errors)
	for item in [BranchSystem.ITEM_HISTORIAN_ANSWER_1, BranchSystem.ITEM_HISTORIAN_ANSWER_2, BranchSystem.ITEM_HISTORIAN_ANSWER_3]:
		BranchSystem.collect_item(item)
	if DaySystem.wake_up_cost != DaySystem.WAKE_UP_COST_DEFAULT:
		errors.append("до сдачи Истории пробуждение должно стоить %d" % DaySystem.WAKE_UP_COST_DEFAULT)

	_plan(BranchSystem.STAGE_HISTORIAN_EXAM, errors)
	var npc: EncounterNpc = load(HISTORIAN).instantiate()
	add_child(npc)
	await get_tree().process_frame
	await _talk(npc, BranchSystem.COMIC_HISTORIAN_EXAM, errors)
	if BranchSystem.get_state(BranchSystem.STAGE_HISTORIAN_EXAM) != BranchSystem.State.COMPLETED:
		errors.append("после сдачи этап 3 не COMPLETED")
	if not BranchSystem.is_branch_completed(BranchSystem.BRANCH_HISTORIAN):
		errors.append("ветка Историка не завершена после трёх этапов")
	if DaySystem.wake_up_cost != 1:
		errors.append("награда Историка: проснуться должно стоить 1, стоит %d" % DaySystem.wake_up_cost)
	if EnerginkaSystem.max_energinka != 5 or EnerginkaSystem.energinka_pool != 2:
		errors.append("награда не должна менять максимум энергинок (ожидалось 2/5, было %d/%d)" % [
			EnerginkaSystem.energinka_pool, EnerginkaSystem.max_energinka])
	# Пользу награды игрок видит на следующем дне: экран пробуждения рисует 1 энергинку на кнопке «да».
	DaySystem._show_wake_up_screen()
	await get_tree().process_frame
	var icons := _count_button_icons(DaySystem._wake_up_layer)
	if icons != 1:
		errors.append("на кнопке «да» должна быть 1 энергинка после награды, было %d" % icons)
	DaySystem._start_day()
	await get_tree().process_frame
	if EnerginkaSystem.energinka_pool != EnerginkaSystem.max_energinka - 1:
		errors.append("пробуждение после награды должно списать 1 энергинку")
	DaySystem._clear_layer(DaySystem._overlay_layer)
	get_tree().paused = false
	npc.queue_free()
	await get_tree().process_frame
	print("  OK  этап 3: сдача и награда «проснуться за 1»")


func _count_button_icons(layer: CanvasLayer) -> int:
	if layer == null:
		return -1
	var count := 0
	for button in _find_all(layer, "Button"):
		count += _find_all(button, "TextureRect").size()
	return count


func _find_all(node: Node, cls: String) -> Array:
	var out: Array = []
	if node.is_class(cls):
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_all(child, cls))
	return out


func _test_spawn_in_historian_cabinet(errors: Array) -> void:
	_reset()
	_force_historian_cabinet_choice()
	var anchor := Marker3D.new()
	anchor.position = Vector3(0, 1.5, 0)
	add_child(anchor)
	if not CabinetPool.select_cabinet(&"cabinet_slot_1", &"historian_cabinet"):
		errors.append("не удалось вытащить Кабинет Историка")
	CabinetPool.apply_to_anchor(&"cabinet_slot_1", anchor)
	await get_tree().process_frame
	var historian := anchor.get_node_or_null(^"Historian") as EncounterNpc
	if historian == null:
		errors.append("Историк — стабильное содержимое Кабинета Историка: должен стоять там и без активного этапа")
	elif historian.npc_id != BranchSystem.NPC_HISTORIAN:
		errors.append("у Историка в кабинете npc_id должен быть historian")
	anchor.queue_free()
	await get_tree().process_frame
	print("  OK  Историк стоит в Кабинете Историка всегда")


func _test_scale(errors: Array) -> void:
	var hist_size := SychUnit.quad_size(290, 478, SychUnit.ADULT_HEIGHT_SYCH_UNITS)
	if hist_size.y <= SychUnit.HEIGHT_M:
		errors.append("преподаватель должен быть выше 1 СЫЧа")
	var packed: PackedScene = load(HISTORIAN)
	var npc: Node3D = packed.instantiate()
	add_child(npc)
	await get_tree().process_frame
	var mesh := npc.get_node(^"MeshInstance3D") as MeshInstance3D
	var quad := mesh.mesh as QuadMesh
	if quad == null or quad.size.y <= SychUnit.HEIGHT_M + 0.2:
		errors.append("спрайт Историка должен быть заметно выше Сыча (2 м)")
	if abs(quad.size.y - SychUnit.meters(SychUnit.ADULT_HEIGHT_SYCH_UNITS)) > 0.05:
		errors.append("рост Историка должен быть %.2f м (%.2f СЫЧа)" % [
			SychUnit.meters(SychUnit.ADULT_HEIGHT_SYCH_UNITS), SychUnit.ADULT_HEIGHT_SYCH_UNITS])
	npc.queue_free()

	var sych: CharacterBody3D = load("res://scenes/actors/sych/sych.tscn").instantiate()
	add_child(sych)
	await get_tree().process_frame
	var rest: float = sych._body_rest_y
	if rest < 0.99:
		errors.append("спрайт Сыча должен стоять на полу (rest y ≈ 1 м)")
	for t in [0.0, 0.3, 0.7, 1.1, 2.4]:
		sych.run_time = t
		if sych._run_sprite_y(true) < rest - 0.0001:
			errors.append("на беге спрайт Сыча уходит ниже покоя (ноги в полу)")
			break
	if abs(sych._run_sprite_y(false) - rest) > 0.0001:
		errors.append("в покое спрайт Сыча не на rest y")
	sych.queue_free()
	await get_tree().process_frame
	print("  OK  масштаб в сычовых единицах и ноги на полу")


func _force_historian_cabinet_choice() -> void:
	var choice: Array[StringName] = [&"historian_cabinet", &"classroom"]
	CabinetPool._wing_cabinet_choices[CabinetPool.Wing.FIRST_FLOOR_LEFT] = choice
