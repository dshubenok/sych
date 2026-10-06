extends Node

## Поведение входа в кабинеты:
##   godot --headless --path . res://scenes/tools/test_cabinet_entry.tscn
## 1) у кабинета нет старого 2D Title, есть 3D-вывеска CabinetSign;
## 2) 2D-крошки в кабинете скрыты;
## 3) над дверью значок энергинки; выбор кабинетов из двух; стоимость 2/1.

const DOOR := "res://scenes/world/streaming_door.tscn"
const BREADCRUMB := "res://scenes/ui/location_breadcrumb.tscn"

func _ready() -> void:
	DaySystem.end_on_failed_spend = false
	await get_tree().process_frame
	var errors: Array[String] = []
	var stream := Node3D.new()
	stream.name = "StreamedLocations"
	add_child(stream)
	LocationManager.set_stream_container(stream)

	await _test_no_2d_title(errors)
	await _test_breadcrumb_hidden(errors)
	await _test_cabinet_choice_and_cost(errors)
	await _test_energinka_gate(errors)
	await _test_end_day_button(errors)

	for e in errors:
		print("  [ERROR] %s" % e)
	if errors.is_empty():
		print("[test_cabinet_entry] OK")
	else:
		print("[test_cabinet_entry] ПРОВАЛ — ошибок: %d" % errors.size())
	get_tree().quit(errors.size())


func _test_no_2d_title(errors: Array) -> void:
	CabinetPool.reroll_sharaga()
	var anchor := Marker3D.new()
	add_child(anchor)
	if not CabinetPool.select_cabinet(&"cabinet_slot_1", &"classroom"):
		errors.append("не удалось вытащить базовый кабинет для вывески")
	var cabinet_id: StringName = CabinetPool.apply_to_anchor(&"cabinet_slot_1", anchor)
	await get_tree().process_frame
	if cabinet_id == &"" or anchor.get_node_or_null(^"CabinetSign") == null:
		errors.append("cabinet_slot_1: нет 3D-вывески CabinetSign после apply_to_anchor")
	print("  OK  3D-вывеска без 2D Title  (cabinet=%s)" % cabinet_id)
	anchor.queue_free()
	CabinetPool.reroll_sharaga()
	await get_tree().process_frame


func _test_breadcrumb_hidden(errors: Array) -> void:
	var bc: Node = load(BREADCRUMB).instantiate()
	add_child(bc)
	await get_tree().process_frame
	bc._apply(&"cabinet_slot_1")
	var label := bc.get_node(^"Label") as Label
	if label.visible or not label.text.is_empty():
		errors.append("крошки в кабинете не скрыты (2D-имя кабинета)")
	bc._apply(&"first_floor")
	if not label.visible:
		errors.append("крошки на этаже скрыты, хотя не должны")
	print("  OK  2D-крошки скрыты в кабинете")
	bc.queue_free()
	await get_tree().process_frame


func _test_cabinet_choice_and_cost(errors: Array) -> void:
	CabinetPool.reroll_sharaga()
	if CabinetPool.energinka_cost(&"demonologist") != 2 or CabinetPool.energinka_cost(&"library") != 2:
		errors.append("демонолог/библиотека должны стоить 2")
	if CabinetPool.energinka_cost(&"toilet") != 1 or CabinetPool.energinka_cost(&"classroom") != 1:
		errors.append("туалет и classroom должны стоить 1")
	if not CabinetPool._allowed_in_wing(&"classroom", CabinetPool.Wing.FIRST_FLOOR_LEFT) \
			or not CabinetPool._allowed_in_wing(&"classroom", CabinetPool.Wing.FIRST_FLOOR_RIGHT) \
			or not CabinetPool._allowed_in_wing(&"classroom", CabinetPool.Wing.SECOND_FLOOR_LEFT) \
			or not CabinetPool._allowed_in_wing(&"classroom", CabinetPool.Wing.SECOND_FLOOR_RIGHT):
		errors.append("classroom должен появляться в любом крыле без условий")
	if not CabinetPool.is_base_cabinet(&"classroom") or CabinetPool.is_base_cabinet(&"library"):
		errors.append("базовый кабинет — только classroom")
	if CabinetPool._allowed_in_wing(&"demonologist", CabinetPool.Wing.FIRST_FLOOR_LEFT) \
			or CabinetPool._allowed_in_wing(&"demonologist", CabinetPool.Wing.SECOND_FLOOR_RIGHT):
		errors.append("демонолог должен быть только справа на 1 этаже")
	if not CabinetPool._allowed_in_wing(&"demonologist", CabinetPool.Wing.FIRST_FLOOR_RIGHT):
		errors.append("демонолог должен быть справа на 1 этаже")
	if CabinetPool._allowed_in_wing(&"library", CabinetPool.Wing.FIRST_FLOOR_LEFT) \
			or CabinetPool._allowed_in_wing(&"library", CabinetPool.Wing.FIRST_FLOOR_RIGHT) \
			or CabinetPool._allowed_in_wing(&"library", CabinetPool.Wing.SECOND_FLOOR_LEFT):
		errors.append("библиотека должна быть только справа на 2 этаже")
	if not CabinetPool._allowed_in_wing(&"library", CabinetPool.Wing.SECOND_FLOOR_RIGHT):
		errors.append("библиотека должна быть справа на 2 этаже")
	if CabinetPool.energinka_cost(&"cafeteria") != 1 or CabinetPool.energinka_cost(&"gym") != 1:
		errors.append("столовая и спортзал должны стоить 1")
	var left: Array[StringName] = CabinetPool.cabinet_choice_for(&"cabinet_slot_1")
	if left.size() != 2:
		errors.append("выбор кабинетов слева должен быть из 2 кабинетов, было %d" % left.size())
	if CabinetPool.cabinet_choice_for(&"cabinet_slot_1") != left:
		errors.append("повторный выбор кабинетов той же двери должен совпадать")
	if CabinetPool.cabinet_choice_for(&"cabinet_slot_2") != left or CabinetPool.cabinet_choice_for(&"cabinet_slot_3") != left:
		errors.append("все закрытые двери левого крыла 1 этажа должны показывать один выбор кабинетов")
	if left.has(&"demonologist") or left.has(&"library") or left.has(&"cafeteria"):
		errors.append("на 1 этаже слева появились кабинеты 2 этажа или демонолог")
	if left.has(&"historian_cabinet"):
		errors.append("кабинет Историка в выборе до демонолога")
	var right: Array[StringName] = CabinetPool.cabinet_choice_for(&"cabinet_slot_4")
	if CabinetPool.cabinet_choice_for(&"cabinet_slot_5") != right or CabinetPool.cabinet_choice_for(&"cabinet_slot_6") != right:
		errors.append("все закрытые двери правого крыла 1 этажа должны показывать один выбор кабинетов")
	if right.has(&"library"):
		errors.append("библиотека попала в выбор 1 этажа")
	if right.has(&"historian_cabinet"):
		errors.append("кабинет Историка в правом выборе до демонолога")
	var f2_left: Array[StringName] = CabinetPool.cabinet_choice_for(&"cabinet_slot_7")
	if f2_left.size() != 2:
		errors.append("выбор кабинетов 2 этажа слева должен быть из 2 кабинетов, было %d" % f2_left.size())
	if not f2_left.has(&"classroom") and not f2_left.has(&"cafeteria"):
		errors.append("в левом выборе 2 этажа нет ни classroom, ни столовой")
	if CabinetPool.cabinet_choice_for(&"cabinet_slot_8") != f2_left:
		errors.append("обе закрытые двери левого крыла 2 этажа должны показывать один выбор кабинетов")
	if f2_left.has(&"demonologist") or f2_left.has(&"library"):
		errors.append("демонолог или библиотека попали в левое крыло 2 этажа")
	if f2_left.has(&"gym"):
		errors.append("спортзал в выборе до столовой")
	var f2_right: Array[StringName] = CabinetPool.cabinet_choice_for(&"cabinet_slot_9")
	if CabinetPool.cabinet_choice_for(&"cabinet_slot_10") != f2_right:
		errors.append("обе закрытые двери правого крыла 2 этажа должны показывать один выбор кабинетов")
	if f2_right.has(&"gym"):
		errors.append("спортзал справа в выборе до столовой")
	var picked: StringName = left[0]
	if not CabinetPool.select_cabinet(&"cabinet_slot_1", picked):
		errors.append("не удалось вытащить кабинет")
	var left_after: Array[StringName] = CabinetPool.cabinet_choice_for(&"cabinet_slot_2")
	if left_after != CabinetPool.cabinet_choice_for(&"cabinet_slot_3"):
		errors.append("после открытия двери оставшиеся двери крыла должны иметь один новый выбор кабинетов")
	if not CabinetPool.is_base_cabinet(picked) and left_after.has(picked):
		errors.append("вытащенный кабинет снова попал в выбор крыла")
	if CabinetPool.cabinet_choice_for(&"cabinet_slot_4") != right:
		errors.append("выбор правого крыла изменился от открытия левой двери")
	if CabinetPool.cabinet_choice_for(&"cabinet_slot_7") != f2_left:
		errors.append("выбор 2 этажа изменился от открытия двери 1 этажа")
	CabinetPool.reroll_sharaga()
	if CabinetPool._allowed_cabinets(CabinetPool.Wing.SECOND_FLOOR_LEFT).has(&"gym") \
			or CabinetPool._allowed_cabinets(CabinetPool.Wing.SECOND_FLOOR_RIGHT).has(&"gym"):
		errors.append("спортзал в пуле до столовой")
	if not CabinetPool.select_cabinet(&"cabinet_slot_7", &"cafeteria"):
		errors.append("столовая не взялась на 2 этаже")
	if not CabinetPool._allowed_cabinets(CabinetPool.Wing.SECOND_FLOOR_LEFT).has(&"gym") \
			and not CabinetPool._allowed_cabinets(CabinetPool.Wing.SECOND_FLOOR_RIGHT).has(&"gym"):
		errors.append("после столовой спортзал должен появиться в пуле 2 этажа")
	var f2_right_after: Array[StringName] = CabinetPool.cabinet_choice_for(&"cabinet_slot_9")
	if f2_right_after.has(&"cafeteria"):
		errors.append("столовая осталась в выборе другого крыла")
	if not CabinetPool.select_cabinet(&"cabinet_slot_9", &"cafeteria"):
		errors.append("повтор столовой должен открыть пустой кабинет")
	if not CabinetPool.is_empty_cabinet(&"cabinet_slot_9"):
		errors.append("повтор специального кабинета должен дать пустой слот")
	if CabinetPool.get_selected_cabinet(&"cabinet_slot_7") != &"cafeteria":
		errors.append("первая столовая не должна сброситься")
	CabinetPool.reroll_sharaga()
	if not CabinetPool.select_cabinet(&"cabinet_slot_5", &"classroom"):
		errors.append("classroom не взялся справа")
	if CabinetPool._used.has(&"classroom"):
		errors.append("базовый кабинет не должен помечаться занятым")
	var right_after: Array[StringName] = CabinetPool.cabinet_choice_for(&"cabinet_slot_6")
	if right_after.has(&"classroom") and not CabinetPool.select_cabinet(&"cabinet_slot_6", &"classroom"):
		errors.append("classroom был в новом выборе, но повторно не взялся")
	print("  OK  выбор кабинетов из двух и стоимость")
	CabinetPool.reroll_sharaga()


func _test_energinka_gate(errors: Array) -> void:
	CabinetPool.reroll_sharaga()
	var door: StreamingDoor = load(DOOR).instantiate()
	door.target_location_id = &"cabinet_slot_1"
	door.in_place = true
	var anchor := Marker3D.new()
	anchor.name = "SignAnchor"
	add_child(anchor)
	add_child(door)
	door.sign_anchor = NodePath("../SignAnchor")
	await get_tree().process_frame
	var label := door.get_node(^"TargetLabel") as Label3D
	if label.visible or not label.text.is_empty():
		errors.append("над дверью кабинета висит 2D-имя: '%s'" % label.text)
	var icon := door.get_node_or_null(^"EnerginkaIcon") as MeshInstance3D
	if icon == null or not icon.visible:
		errors.append("над входом в кабинет нет значка энергинки")
	var cabinet_choice: Array[StringName] = CabinetPool.cabinet_choice_for(&"cabinet_slot_1")
	if cabinet_choice.is_empty():
		errors.append("пустой выбор кабинетов для cabinet_slot_1")
		door.queue_free()
		anchor.queue_free()
		return
	var cheap: StringName = &""
	var expensive: StringName = &""
	for cabinet_id in cabinet_choice:
		if CabinetPool.energinka_cost(cabinet_id) == 1:
			cheap = cabinet_id
		if CabinetPool.energinka_cost(cabinet_id) == 2:
			expensive = cabinet_id
	var pick: StringName = cheap if cheap != &"" else cabinet_choice[0]
	var cost: int = CabinetPool.energinka_cost(pick)
	EnerginkaSystem.energinka_pool = 0
	if door.select_cabinet(pick):
		errors.append("выбор прошёл без энергинок")
	if EnerginkaSystem.energinka_pool != 0:
		errors.append("пул энергинок изменился при отказе выбора")
	if icon == null or not icon.visible:
		errors.append("значок энергинки пропал после отказа")
	EnerginkaSystem.energinka_pool = cost
	if not door.select_cabinet(pick):
		errors.append("выбор не прошёл при наличии энергинок")
	if EnerginkaSystem.energinka_pool != 0:
		errors.append("ожидали списание %d, осталось %d" % [cost, EnerginkaSystem.energinka_pool])
	if icon and icon.visible:
		errors.append("значок энергинки остался после открытия")
	if not LocationManager.is_loaded(&"cabinet_slot_1"):
		errors.append("кабинет не отмечен открытым после оплаты")
	if anchor.get_node_or_null(^"CabinetSign") == null:
		errors.append("после выбора нет 3D-вывески в якоре")
	if not door.select_cabinet(pick):
		errors.append("повторное открытие не удалось")
	if EnerginkaSystem.energinka_pool != 0:
		errors.append("энергинки списались повторно, осталось %d" % EnerginkaSystem.energinka_pool)
	EnerginkaSystem.energinka_pool = 0
	var failed: Array = [false]
	var on_fail := func(_amount: int) -> void: failed[0] = true
	EnerginkaSystem.energinka_spend_failed.connect(on_fail)
	if EnerginkaSystem.spend_energinka(1) or not failed[0]:
		errors.append("нулевой пул должен давать неудачную трату")
	EnerginkaSystem.energinka_spend_failed.disconnect(on_fail)
	if expensive != &"":
		print("  OK  вход за энергинку (в выборе был и вариант за 2)")
	else:
		print("  OK  вход в кабинет за энергинку")
	door.queue_free()
	anchor.queue_free()
	LocationManager.reset_streamed()
	CabinetPool.reroll_sharaga()
	await get_tree().process_frame


func _test_end_day_button(errors: Array) -> void:
	var hud: Node = load("res://scenes/ui/energinka_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var button := hud.get_node_or_null(^"Root/TopRight/EndDayButton") as Button
	if button == null or button.text != "Ой всё":
		errors.append("нет кнопки «Ой всё» под энергинками")
	else:
		print("  OK  кнопка завершения дня")
	var refill := hud.get_node_or_null(^"Root/TopRight/RefillEnerginkaButton") as Button
	if refill == null:
		errors.append("нет тестовой кнопки «Восстановить энергинки»")
	else:
		EnerginkaSystem.energinka_pool = 1
		hud._on_refill_pressed()
		if EnerginkaSystem.energinka_pool != EnerginkaSystem.max_energinka:
			errors.append("кнопка не восстановила весь пул энергинок")
		else:
			print("  OK  восстановить энергинки")
	hud.queue_free()
	await get_tree().process_frame
