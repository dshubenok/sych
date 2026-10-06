extends Node

## Квест историка на ветке Демонолога:
##   godot --headless --path . res://scenes/tools/test_historian_quest.tscn

const HISTORIAN := "res://scenes/actors/npcs/historian.tscn"
const BOARD_UI := "res://scenes/ui/energy_board_ui.tscn"
const RUMOR := "До меня дошел слух, что наш жуткий Демонолог был когда-то студентом преподавателя Истории. Проверим из первых рук."


func _ready() -> void:
	DaySystem.end_on_failed_spend = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: Array[String] = []
	EnergySystem.reset_progress()
	QuestSystem.reset_progress()
	RoomPool._reset_day()

	await _test_board_and_unlock(errors)
	await _test_spawn_in_history(errors)
	await _test_dialog_reward(errors)
	await _test_scale_and_banner(errors)

	EnergySystem.reset_progress()
	QuestSystem.reset_progress()
	RoomPool._reset_day()
	for e in errors:
		print("  [ERROR] %s" % e)
	if errors.is_empty():
		print("[test_historian_quest] OK")
	else:
		print("[test_historian_quest] ПРОВАЛ — ошибок: %d" % errors.size())
	get_tree().quit(errors.size())


func _test_board_and_unlock(errors: Array) -> void:
	EnergySystem.reset_progress()
	QuestSystem.reset_progress()
	if not QuestSystem.has_quest_for_slot(4):
		errors.append("первое сердце ветки Демонолога пусто")
	if QuestSystem.get_quest_id_for_slot(4) != QuestSystem.QUEST_FIND_HISTORIAN:
		errors.append("слот 4 должен быть find_historian")
	if not QuestSystem.is_slot_unlocked(4):
		errors.append("первое сердце Демонолога должно быть открыто с утра")
	if QuestSystem.is_slot_unlocked(5):
		errors.append("второе сердце открылось до выполнения историка")
	if QuestSystem.set_pending(QuestSystem.QUEST_DEMONOLOG_2):
		errors.append("второе сердце приняло энергию до историка")
	if not QuestSystem.set_pending(QuestSystem.QUEST_FIND_HISTORIAN):
		errors.append("не удалось вложить энергию в историка")
	if not EnergySystem.try_spend(1):
		errors.append("не удалось списать энергию за квест")
	var spawned: Array = QuestSystem.confirm_pending()
	if spawned != [QuestSystem.QUEST_FIND_HISTORIAN]:
		errors.append("confirm не заспавнил find_historian")
	if QuestSystem.get_state(QuestSystem.QUEST_FIND_HISTORIAN) != QuestSystem.State.ACTIVE:
		errors.append("после ОК квест историка не ACTIVE")
	if QuestSystem.get_board_message() != RUMOR:
		errors.append("нет слуха для ворчания")
	if QuestSystem.get_confirmed_description(4) != RUMOR:
		errors.append("наведение на сердце историка не возвращает слух")
	if QuestSystem.get_confirmed_description(0) != "":
		errors.append("неподтверждённый Котик отдаёт описание")
	if EnergySystem.current_energy != 4:
		errors.append("после взятия квеста энергия должна быть 4, было %d" % EnergySystem.current_energy)

	var ui: EnergyBoardUi = load(BOARD_UI).instantiate()
	add_child(ui)
	await get_tree().process_frame
	ui.setup(8)
	await get_tree().process_frame
	var message := ui.get_node("Root/BoardFrame/BoardContent/Message") as Label
	if message.text == RUMOR:
		errors.append("слух висит на доске, а должен быть только нижним ворчанием")
	ui.queue_free()
	await get_tree().process_frame
	print("  OK  доска: слух не на доске, первое сердце")


func _test_spawn_in_history(errors: Array) -> void:
	EnergySystem.reset_progress()
	QuestSystem.reset_progress()
	RoomPool._reset_day()
	_force_history_offer()
	var closed := Marker3D.new()
	closed.position = Vector3(0, 1.5, 0)
	add_child(closed)
	if not RoomPool.commit(&"kabinet_1", &"history"):
		errors.append("не удалось открыть кабинет истории")
	RoomPool.apply_to_anchor(&"kabinet_1", closed)
	await get_tree().process_frame
	if closed.get_node_or_null(^"Historian") != null:
		errors.append("историк появился до взятия квеста")

	QuestSystem.set_pending(QuestSystem.QUEST_FIND_HISTORIAN)
	QuestSystem.confirm_pending()
	await get_tree().process_frame
	if closed.get_node_or_null(^"Historian") == null:
		errors.append("историк не появился в уже открытой истории")

	RoomPool._reset_day()
	_force_history_offer()
	var next := Marker3D.new()
	next.position = Vector3(0, 1.5, 0)
	add_child(next)
	if not RoomPool.commit(&"kabinet_2", &"history"):
		errors.append("не удалось открыть историю после спавна квеста")
	RoomPool.apply_to_anchor(&"kabinet_2", next)
	await get_tree().process_frame
	if next.get_node_or_null(^"Historian") == null:
		errors.append("историк не появился при открытии истории с активным квестом")
	closed.queue_free()
	next.queue_free()
	await get_tree().process_frame
	print("  OK  спавн историка в кабинете истории")


func _test_dialog_reward(errors: Array) -> void:
	EnergySystem.reset_progress()
	QuestSystem.reset_progress()
	QuestSystem.set_pending(QuestSystem.QUEST_FIND_HISTORIAN)
	QuestSystem.confirm_pending()
	var data: Dictionary = DialogSystem._load_dialog("historian_intro")
	if data.get("panels", []).size() != 4:
		errors.append("диалог историка должен быть из 4 картинок")
	var npc: QuestNpc = load(HISTORIAN).instantiate()
	add_child(npc)
	await get_tree().process_frame
	npc._player_in_range = true
	npc._interact()
	await get_tree().process_frame
	if not DialogSystem.is_active():
		errors.append("E не открыл диалог историка")
	else:
		DialogSystem._active_player._close()
		await get_tree().process_frame
		await get_tree().process_frame
	if QuestSystem.get_state(QuestSystem.QUEST_FIND_HISTORIAN) != QuestSystem.State.COMPLETED:
		errors.append("после диалога квест не COMPLETED")
	if EnergySystem.max_energy != 6 or EnergySystem.current_energy != 6:
		errors.append("после диалога пул должен стать 6/6, было %d/%d" % [
			EnergySystem.current_energy, EnergySystem.max_energy])
	var banner := get_tree().root.get_node_or_null(^"QuestCompleteBanner")
	if banner == null:
		errors.append("после квеста нет экрана «Ура!»")
	else:
		var msg := banner.find_child("Message", true, false) as Label
		if msg == null or msg.text != QuestSystem.COMPLETE_BANNER_TEXT:
			errors.append("текст экрана выполнения квеста неверный")
	if EnergySystem.collect_upgrade(&"historian_quest"):
		errors.append("повтор диалога не должен давать вторую энергинку")
	if not QuestSystem.is_slot_unlocked(5):
		errors.append("второе сердце ветки Демонолога не открылось")
	if not QuestSystem.set_pending(QuestSystem.QUEST_DEMONOLOG_2):
		errors.append("во второе сердце нельзя вложить энергию после историка")
	npc._player_in_range = true
	npc._interact()
	await get_tree().process_frame
	if DialogSystem.is_active():
		errors.append("после квеста снова открылся диалог")
		DialogSystem._active_player._close()
		await get_tree().process_frame
	npc.queue_free()
	await get_tree().process_frame
	print("  OK  диалог, +1 к пулу, следующее сердце")


func _test_scale_and_banner(errors: Array) -> void:
	var hist_size := SychScale.quad_size(290, 478, SychScale.ADULT_HEIGHT_SYCHS)
	if hist_size.y <= SychScale.HEIGHT_M:
		errors.append("преподаватель должен быть выше 1 сыча")
	var packed: PackedScene = load(HISTORIAN)
	var npc: Node3D = packed.instantiate()
	add_child(npc)
	await get_tree().process_frame
	var mesh := npc.get_node(^"MeshInstance3D") as MeshInstance3D
	var quad := mesh.mesh as QuadMesh
	if quad == null or quad.size.y <= SychScale.HEIGHT_M + 0.2:
		errors.append("спрайт историка должен быть заметно выше Сыча (2 м)")
	if abs(quad.size.y - SychScale.meters(SychScale.ADULT_HEIGHT_SYCHS)) > 0.05:
		errors.append("рост историка должен быть %.2f м (%.2f сыча)" % [
			SychScale.meters(SychScale.ADULT_HEIGHT_SYCHS), SychScale.ADULT_HEIGHT_SYCHS])
	npc.queue_free()

	var player: CharacterBody3D = load("res://scenes/actors/player/player.tscn").instantiate()
	add_child(player)
	await get_tree().process_frame
	var rest: float = player._body_rest_y
	if rest < 0.99:
		errors.append("спрайт Сыча должен стоять на полу (rest y ≈ 1 м)")
	for t in [0.0, 0.3, 0.7, 1.1, 2.4]:
		player.run_time = t
		if player._run_sprite_y(true) < rest - 0.0001:
			errors.append("на беге спрайт Сыча уходит ниже покоя (ноги в полу)")
			break
	if abs(player._run_sprite_y(false) - rest) > 0.0001:
		errors.append("в покое спрайт Сыча не на rest y")
	player.queue_free()
	await get_tree().process_frame
	print("  OK  масштаб в сычах и ноги на полу")


func _force_history_offer() -> void:
	RoomPool._used[&"demonologist"] = true
	var offer: Array[StringName] = [&"history", &"classroom"]
	RoomPool._wing_offers[RoomPool.Wing.F1_LEFT] = offer
