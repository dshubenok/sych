extends Node

## Этап ветки «найти Историка»:
##   godot --headless --path . res://scenes/tools/test_historian_branch_stage.tscn

const HISTORIAN := "res://scenes/actors/npcs/historian.tscn"
const CORKBOARD_UI := "res://scenes/ui/corkboard_ui.tscn"
const RUMOR := "До меня дошел слух, что наш жуткий Демонолог был когда-то студентом преподавателя Истории. Проверим из первых рук."


func _ready() -> void:
	DaySystem.end_on_failed_spend = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: Array[String] = []
	EnerginkaSystem.reset_progress()
	BranchSystem.reset_progress()
	CabinetPool.reroll_sharaga()

	await _test_corkboard_and_unlock(errors)
	await _test_spawn_in_historian_cabinet(errors)
	await _test_comic_dialogue_reward(errors)
	await _test_scale_and_banner(errors)

	EnerginkaSystem.reset_progress()
	BranchSystem.reset_progress()
	CabinetPool.reroll_sharaga()
	for e in errors:
		print("  [ERROR] %s" % e)
	if errors.is_empty():
		print("[test_historian_branch_stage] OK")
	else:
		print("[test_historian_branch_stage] ПРОВАЛ — ошибок: %d" % errors.size())
	get_tree().quit(errors.size())


func _test_corkboard_and_unlock(errors: Array) -> void:
	EnerginkaSystem.reset_progress()
	BranchSystem.reset_progress()
	if not BranchSystem.has_branch_stage_for_slot(4):
		errors.append("первое сердечко ветки Историка пусто")
	if BranchSystem.get_branch_stage_id_for_slot(4) != BranchSystem.BRANCH_STAGE_FIND_HISTORIAN:
		errors.append("слот 4 должен быть find_historian")
	if not BranchSystem.is_slot_unlocked(4):
		errors.append("первое сердечко Историка должно быть открыто с утра")
	if not BranchSystem.invest_energinka(BranchSystem.BRANCH_STAGE_FIND_HISTORIAN):
		errors.append("не удалось вложить энергинку в Историка")
	if not EnerginkaSystem.spend_energinka(1):
		errors.append("не удалось потратить энергинку за этап ветки")
	var planned: Array = BranchSystem.confirm_plan()
	if planned != [BranchSystem.BRANCH_STAGE_FIND_HISTORIAN]:
		errors.append("confirm_plan не запланировал find_historian")
	if BranchSystem.get_state(BranchSystem.BRANCH_STAGE_FIND_HISTORIAN) != BranchSystem.State.ACTIVE:
		errors.append("после ОК этап Историка не ACTIVE")
	if BranchSystem.get_corkboard_message() != RUMOR:
		errors.append("нет слуха для ворчания")
	if BranchSystem.get_confirmed_description(4) != RUMOR:
		errors.append("наведение на сердечко Историка не возвращает слух")
	if BranchSystem.get_confirmed_description(0) != "":
		errors.append("неподтверждённый Котик отдаёт описание")
	if EnerginkaSystem.energinka_pool != 4:
		errors.append("после планирования этапа пул энергинок должен быть 4, было %d" % EnerginkaSystem.energinka_pool)

	var ui: CorkboardUi = load(CORKBOARD_UI).instantiate()
	add_child(ui)
	await get_tree().process_frame
	ui.setup(8)
	await get_tree().process_frame
	var message := ui.get_node("Root/BoardFrame/BoardContent/Message") as Label
	if message.text == RUMOR:
		errors.append("слух висит на доске, а должен быть только нижним ворчанием")
	ui.queue_free()
	await get_tree().process_frame
	print("  OK  доска: слух не на доске, первое сердечко")


func _test_spawn_in_historian_cabinet(errors: Array) -> void:
	EnerginkaSystem.reset_progress()
	BranchSystem.reset_progress()
	CabinetPool.reroll_sharaga()
	_force_historian_cabinet_choice()
	var closed := Marker3D.new()
	closed.position = Vector3(0, 1.5, 0)
	add_child(closed)
	if not CabinetPool.select_cabinet(&"cabinet_slot_1", &"historian_cabinet"):
		errors.append("не удалось открыть кабинет Историка")
	CabinetPool.apply_to_anchor(&"cabinet_slot_1", closed)
	await get_tree().process_frame
	if closed.get_node_or_null(^"Historian") != null:
		errors.append("Историк появился до планирования этапа")

	BranchSystem.invest_energinka(BranchSystem.BRANCH_STAGE_FIND_HISTORIAN)
	BranchSystem.confirm_plan()
	await get_tree().process_frame
	if closed.get_node_or_null(^"Historian") == null:
		errors.append("Историк не появился в уже открытом кабинете Историка")

	CabinetPool.reroll_sharaga()
	_force_historian_cabinet_choice()
	var next := Marker3D.new()
	next.position = Vector3(0, 1.5, 0)
	add_child(next)
	if not CabinetPool.select_cabinet(&"cabinet_slot_2", &"historian_cabinet"):
		errors.append("не удалось открыть кабинет Историка после планирования этапа")
	CabinetPool.apply_to_anchor(&"cabinet_slot_2", next)
	await get_tree().process_frame
	if next.get_node_or_null(^"Historian") == null:
		errors.append("Историк не появился при открытии кабинета Историка с активным этапом")
	closed.queue_free()
	next.queue_free()
	await get_tree().process_frame
	print("  OK  спавн Историка в кабинете Историка")


func _test_comic_dialogue_reward(errors: Array) -> void:
	EnerginkaSystem.reset_progress()
	BranchSystem.reset_progress()
	BranchSystem.invest_energinka(BranchSystem.BRANCH_STAGE_FIND_HISTORIAN)
	BranchSystem.confirm_plan()
	var data: Dictionary = ComicDialogueSystem._load_comic_dialogue("historian_intro")
	if data.get("frames", []).size() != 4:
		errors.append("комиксный диалог Историка должен быть из 4 кадров")
	var npc: BranchStageNpc = load(HISTORIAN).instantiate()
	add_child(npc)
	await get_tree().process_frame
	npc._sych_in_range = true
	npc._interact()
	await get_tree().process_frame
	if not ComicDialogueSystem.is_active():
		errors.append("E не открыл комиксный диалог Историка")
	else:
		ComicDialogueSystem._active_player._close()
		await get_tree().process_frame
		await get_tree().process_frame
	if BranchSystem.get_state(BranchSystem.BRANCH_STAGE_FIND_HISTORIAN) != BranchSystem.State.COMPLETED:
		errors.append("после комиксного диалога этап ветки не COMPLETED")
	if EnerginkaSystem.max_energinka != 6 or EnerginkaSystem.energinka_pool != 6:
		errors.append("после диалога пул должен стать 6/6, было %d/%d" % [
			EnerginkaSystem.energinka_pool, EnerginkaSystem.max_energinka])
	var banner := get_tree().root.get_node_or_null(^"BranchStageCompleteBanner")
	if banner == null:
		errors.append("после закрытия этапа нет экрана «Ура!»")
	else:
		var msg := banner.find_child("Message", true, false) as Label
		if msg == null or msg.text != BranchSystem.COMPLETE_BANNER_TEXT:
			errors.append("текст экрана закрытия этапа ветки неверный")
	if EnerginkaSystem.collect_upgrade(&"historian_branch_stage"):
		errors.append("повтор диалога не должен давать вторую энергинку")
	npc._sych_in_range = true
	npc._interact()
	await get_tree().process_frame
	if ComicDialogueSystem.is_active():
		errors.append("после закрытия этапа снова открылся комиксный диалог")
		ComicDialogueSystem._active_player._close()
		await get_tree().process_frame
	npc.queue_free()
	await get_tree().process_frame
	print("  OK  комиксный диалог, +1 к пулу")


func _test_scale_and_banner(errors: Array) -> void:
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
