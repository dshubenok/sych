extends Node

## Interaction Model (GDD §7–8, план демо §2.3–2.4, §9):
##   godot --headless --path . res://scenes/tools/test_interaction.tscn
## 1) input-действие interact (E) и поле ворчания постоянное, E не глушит;
## 2) комикс: одно E — ворчание + «+1 энергинка», дальше только пул ворчания;
## 3) записка: одно E — ворчание + экран записки;
## 4) доска: одно E — ворчание + интерфейс; выход: одно E — ворчание + переход;
## 5) платное действие при нехватке энергинок не выполняется, Сыч говорит «Ой, всё».

const NOTE := "res://scenes/world/starosta_note.tscn"
const COMIC := "res://scenes/world/room_comic.tscn"
const CORKBOARD := "res://scenes/world/corkboard.tscn"
const PORTAL := "res://scenes/world/location_portal.tscn"
const PANEL := "res://scenes/ui/vorchanie_panel.tscn"

var _errors: Array[String] = []
var _last_vorchanie: String = ""


func _ready() -> void:
	DaySystem.end_on_failed_spend = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	EnerginkaSystem.reset_progress()
	BranchSystem.reset_progress()
	CabinetPool.reroll_sharaga()
	VorchanieSystem.vorchal.connect(func(text: String) -> void: _last_vorchanie = text)

	await _test_input_and_panel()
	await _test_comic()
	await _test_note()
	await _test_corkboard()
	await _test_portal()
	await _test_oy_vse()

	EnerginkaSystem.reset_progress()
	BranchSystem.reset_progress()
	CabinetPool.reroll_sharaga()
	for e in _errors:
		print("  [ERROR] %s" % e)
	if _errors.is_empty():
		print("[test_interaction] OK")
	else:
		print("[test_interaction] ПРОВАЛ — ошибок: %d" % _errors.size())
	get_tree().quit(_errors.size())


func _check(ok: bool, message: String) -> void:
	if not ok:
		_errors.append(message)


func _press_interact() -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame


func _test_input_and_panel() -> void:
	_check(InputMap.has_action(&"interact"), "нет input-действия interact")
	var has_e := false
	for ev in InputMap.action_get_events(&"interact"):
		if ev is InputEventKey and (ev.keycode == KEY_E or ev.physical_keycode == KEY_E):
			has_e = true
	_check(has_e, "interact не привязан к клавише E")

	var panel: VorchaniePanel = load(PANEL).instantiate()
	add_child(panel)
	await get_tree().process_frame
	_check(VorchanieSystem.has_panel(), "поле ворчания не зарегистрировалось в VorchanieSystem")
	_check(not VorchanieSystem.is_active(), "пустое поле ворчания считается активным")
	_check(panel.visible and panel.get_node(^"Root/Bottom/Bubble").visible, "поле ворчания скрыто, а должно быть зарезервировано постоянно")
	VorchanieSystem.vorchat("Проверка")
	_check(VorchanieSystem.is_active(), "после vorchat реплика не активна")
	_check(VorchaniePanel.seconds_for("Коротко") < VorchaniePanel.seconds_for("Очень длинная реплика, которая висит заметно дольше короткой"),
		"длинная реплика должна висеть дольше короткой")
	_check(not VorchanieSystem.has_method("_input"), "VorchanieSystem всё ещё перехватывает ввод")

	# Пока висит реплика, E доходит до объекта: ворчание не глушит действие.
	var comic: Node3D = load(COMIC).instantiate()
	add_child(comic)
	await get_tree().process_frame
	var interaction: Interaction = comic.interaction
	interaction._sych_in_range = true
	EnerginkaSystem.energinka_pool = 3
	await _press_interact()
	_check(EnerginkaSystem.energinka_pool == 4, "E во время ворчания не выполнил действие (пул %d)" % EnerginkaSystem.energinka_pool)
	comic.queue_free()
	await get_tree().process_frame
	print("  OK  действие interact, постоянное поле ворчания, E не глушится")


func _test_comic() -> void:
	EnerginkaSystem.reset_progress()
	EnerginkaSystem.energinka_pool = 3
	var comic: Node3D = load(COMIC).instantiate()
	add_child(comic)
	await get_tree().process_frame
	var interaction: Interaction = comic.interaction
	_check(interaction != null and interaction.get_node_or_null(^"InteractionPrompt") != null, "у комикса нет подсказки E")
	_check(interaction.interaction_state == &"unread", "комикс не в состоянии unread")
	_last_vorchanie = ""
	interaction._sych_in_range = true
	_check(interaction.interact(), "первое E по комиксу не сработало")
	_check(_last_vorchanie == comic.INTRO_LINE, "первое E: нет ворчания про Пингвина")
	_check(EnerginkaSystem.energinka_pool == 4, "первое E: +1 энергинка не пришла тем же нажатием (пул %d)" % EnerginkaSystem.energinka_pool)
	_check(interaction.interaction_state == &"read", "после чтения состояние не read")
	_check(not interaction.has_action_now(), "после чтения действие всё ещё доступно")
	_last_vorchanie = ""
	_check(interaction.interact(), "повторное E по комиксу не ворчит")
	_check(comic.DONE_LINES.has(_last_vorchanie), "повторное E: реплика не из пула «Всё, начиталась»")
	_check(EnerginkaSystem.energinka_pool == 4, "повторное E снова дало энергинку")
	comic.set_interaction_locked(true)
	_check(not interaction.is_available() and not interaction.interact(), "заблокированный комикс реагирует на E")
	comic.queue_free()
	await get_tree().process_frame
	print("  OK  комикс: ворчание + энергинка одним E, потом пул ворчания")


func _test_note() -> void:
	DaySystem.day_number = 1
	DaySystem.starosta_note_read = false
	var editor_skip: bool = DaySystem.DEV_SKIP_STAROSTA_NOTE and OS.has_feature("editor")
	var note: Node3D = load(NOTE).instantiate()
	add_child(note)
	await get_tree().process_frame
	var interaction: Interaction = note.interaction
	if editor_skip:
		interaction.set_interaction_state(&"unread")
	_last_vorchanie = ""
	interaction._sych_in_range = true
	_check(interaction.interact(), "E по записке не сработало")
	_check(_last_vorchanie == note.vorchanie_before_open, "записка: нет ворчания «тайный поклонник»")
	_check(note._viewer != null, "записка: экран не открылся тем же E")
	_check(get_tree().paused, "записка открыта, а мир не на паузе")
	_check(not interaction.is_available(), "пока записка открыта, E снова доступно")
	if note._viewer:
		note._viewer._on_back()
		await get_tree().process_frame
	_check(not get_tree().paused, "после «Назад» пауза не снята")
	_check(DaySystem.starosta_note_read, "после закрытия записка не считается прочитанной")
	_check(interaction.interaction_state == &"read", "после чтения записка не в состоянии read")
	_last_vorchanie = ""
	interaction.interact()
	_check(_last_vorchanie == "", "повторное открытие записки снова ворчит")
	_check(note._viewer != null, "повторное E не открыло записку")
	if note._viewer:
		note._viewer._on_back()
		await get_tree().process_frame
	note.queue_free()
	await get_tree().process_frame
	DaySystem.starosta_note_read = false
	print("  OK  записка: ворчание + экран одним E")


func _test_corkboard() -> void:
	var board: Corkboard = load(CORKBOARD).instantiate()
	add_child(board)
	await get_tree().process_frame
	var interaction: Interaction = board.interaction
	_last_vorchanie = ""
	interaction._sych_in_range = true
	_check(interaction.interact(), "E по доске не сработало")
	_check(_last_vorchanie == board.OPEN_LINE, "доска: нет ворчания при открытии")
	_check(board._active_ui != null, "доска: интерфейс не открылся тем же E")
	_check(get_tree().paused, "доска открыта, а мир не на паузе")
	if board._active_ui:
		board._active_ui._close()
		await get_tree().process_frame
	_check(not get_tree().paused, "после закрытия доски пауза не снята")
	board.queue_free()
	await get_tree().process_frame
	print("  OK  доска: ворчание + интерфейс одним E")


func _test_portal() -> void:
	BranchSystem.reset_progress()
	var portal: LocationPortal = load(PORTAL).instantiate()
	portal.auto_travel = false
	portal.unlock_on_plan = true
	portal.vorchanie_before_travel = "Наружа. Вэээ."
	portal.target_location_id = &"sharaga"
	add_child(portal)
	await get_tree().process_frame
	var interaction: Interaction = portal.interaction
	_check(interaction != null, "у ручного портала нет Interaction")
	_check(interaction.locked, "выход открыт до подтверждённого плана")
	var travelled: Array = [false]
	interaction.action.connect(func(_i: Interaction) -> void: travelled[0] = true)
	# Переход не выполняем по-настоящему: подменяем _travel проверкой сигнала action.
	portal.set_script(null)
	interaction._sych_in_range = true
	_check(not interaction.interact(), "заблокированный выход сработал")
	interaction.locked = false
	_last_vorchanie = ""
	_check(interaction.interact(), "E по выходу не сработало")
	_check(_last_vorchanie == "Наружа. Вэээ.", "выход: нет ворчания «Наружа. Вэээ.»")
	_check(travelled[0], "выход: переход не запустился тем же E")
	portal.queue_free()
	await get_tree().process_frame
	print("  OK  выход: ворчание + переход одним E, заперт до плана")


func _test_oy_vse() -> void:
	var holder := Node3D.new()
	add_child(holder)
	var interaction := Interaction.ensure(holder)
	interaction.energinka_cost = 1
	interaction.vorchanie_pool = ["Платное"]
	var acted: Array = [false]
	interaction.action.connect(func(_i: Interaction) -> void: acted[0] = true)
	var failed: Array = [false]
	var on_fail := func(_amount: int) -> void: failed[0] = true
	EnerginkaSystem.energinka_spend_failed.connect(on_fail)
	await get_tree().process_frame
	EnerginkaSystem.energinka_pool = 0
	_last_vorchanie = ""
	interaction._sych_in_range = true
	_check(not interaction.interact(), "платное действие прошло при 0 энергинок")
	_check(not acted[0], "действие выполнилось без энергинок")
	_check(failed[0], "нехватка энергинок не дошла до DaySystem (energinka_spend_failed)")
	_check(_last_vorchanie == Interaction.OY_VSE_LINE, "при нехватке энергинок Сыч не сказал «Ой, всё»")
	EnerginkaSystem.energinka_spend_failed.disconnect(on_fail)
	EnerginkaSystem.energinka_pool = 2
	_check(interaction.interact() and acted[0], "платное действие не прошло при наличии энергинок")
	_check(EnerginkaSystem.energinka_pool == 1, "энергинка не списалась за действие")
	interaction.uses_per_day = 1
	acted[0] = false
	interaction.interact()
	_check(not acted[0] and EnerginkaSystem.energinka_pool == 1, "лимит использования на день не сработал")
	DaySystem.day_started.emit(DaySystem.day_number)
	_check(interaction.has_action_now(), "лимит не сбросился с началом дня")
	holder.queue_free()
	await get_tree().process_frame
	print("  OK  «Ой, всё» при нехватке энергинок, лимит на день")
