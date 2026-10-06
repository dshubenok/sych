extends Node

## Поведение входа в кабинеты:
##   godot --headless --path . res://scenes/tools/test_room_entry.tscn
## 1) у кабинета нет старого 2D Title, есть 3D-вывеска RoomSign;
## 2) 2D-крошки в кабинете скрыты;
## 3) над дверью значок энергии; выбор из двух; цена 2/1.

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
	await _test_draft_and_cost(errors)
	await _test_energy_gate(errors)
	await _test_end_day_button(errors)

	for e in errors:
		print("  [ERROR] %s" % e)
	if errors.is_empty():
		print("[test_room_entry] OK")
	else:
		print("[test_room_entry] ПРОВАЛ — ошибок: %d" % errors.size())
	get_tree().quit(errors.size())


func _test_no_2d_title(errors: Array) -> void:
	RoomPool._reset_day()
	var anchor := Marker3D.new()
	add_child(anchor)
	if not RoomPool.commit(&"kabinet_1", &"classroom"):
		errors.append("не удалось выбрать обычный кабинет для вывески")
	var room_id: StringName = RoomPool.apply_to_anchor(&"kabinet_1", anchor)
	await get_tree().process_frame
	if room_id == &"" or anchor.get_node_or_null(^"RoomSign") == null:
		errors.append("kabinet_1: нет 3D-вывески RoomSign после apply_to_anchor")
	print("  OK  3D-вывеска без 2D Title  (room=%s)" % room_id)
	anchor.queue_free()
	RoomPool._reset_day()
	await get_tree().process_frame


func _test_breadcrumb_hidden(errors: Array) -> void:
	var bc: Node = load(BREADCRUMB).instantiate()
	add_child(bc)
	await get_tree().process_frame
	bc._apply(&"kabinet_1")
	var label := bc.get_node(^"Label") as Label
	if label.visible or not label.text.is_empty():
		errors.append("крошки в кабинете не скрыты (2D-имя комнаты)")
	bc._apply(&"etazh_1")
	if not label.visible:
		errors.append("крошки на этаже скрыты, хотя не должны")
	print("  OK  2D-крошки скрыты в кабинете")
	bc.queue_free()
	await get_tree().process_frame


func _test_draft_and_cost(errors: Array) -> void:
	RoomPool._reset_day()
	if RoomPool.entry_cost(&"demonologist") != 2 or RoomPool.entry_cost(&"library") != 2:
		errors.append("демонолог/библиотека должны стоить 2")
	if RoomPool.entry_cost(&"lavatory") != 1 or RoomPool.entry_cost(&"classroom") != 1:
		errors.append("туалет и обычный кабинет должны стоить 1")
	if not RoomPool._allowed_in_wing(&"classroom", RoomPool.Wing.F1_LEFT) \
			or not RoomPool._allowed_in_wing(&"classroom", RoomPool.Wing.F1_RIGHT) \
			or not RoomPool._allowed_in_wing(&"classroom", RoomPool.Wing.F2_LEFT) \
			or not RoomPool._allowed_in_wing(&"classroom", RoomPool.Wing.F2_RIGHT):
		errors.append("обычный кабинет должен появляться в любом крыле без условий")
	if not RoomPool.is_repeatable(&"classroom") or RoomPool.is_repeatable(&"library"):
		errors.append("повторяться может только обычный кабинет")
	if RoomPool._allowed_in_wing(&"demonologist", RoomPool.Wing.F1_LEFT) \
			or RoomPool._allowed_in_wing(&"demonologist", RoomPool.Wing.F2_RIGHT):
		errors.append("демонолог должен быть только справа на 1 этаже")
	if not RoomPool._allowed_in_wing(&"demonologist", RoomPool.Wing.F1_RIGHT):
		errors.append("демонолог должен быть справа на 1 этаже")
	if RoomPool._allowed_in_wing(&"library", RoomPool.Wing.F1_LEFT) \
			or RoomPool._allowed_in_wing(&"library", RoomPool.Wing.F1_RIGHT) \
			or RoomPool._allowed_in_wing(&"library", RoomPool.Wing.F2_LEFT):
		errors.append("библиотека должна быть только справа на 2 этаже")
	if not RoomPool._allowed_in_wing(&"library", RoomPool.Wing.F2_RIGHT):
		errors.append("библиотека должна быть справа на 2 этаже")
	if RoomPool.entry_cost(&"cafeteria") != 1 or RoomPool.entry_cost(&"gym") != 1:
		errors.append("столовая и спортзал должны стоить 1")
	var left: Array[StringName] = RoomPool.offer_for(&"kabinet_1")
	if left.size() != 2:
		errors.append("оффер слева должен быть из 2 кабинетов, было %d" % left.size())
	if RoomPool.offer_for(&"kabinet_1") != left:
		errors.append("повторный оффер той же двери должен совпадать")
	if RoomPool.offer_for(&"kabinet_2") != left or RoomPool.offer_for(&"kabinet_3") != left:
		errors.append("все закрытые двери левого крыла 1 этажа должны показывать один драфт")
	if left.has(&"demonologist") or left.has(&"library") or left.has(&"cafeteria"):
		errors.append("на 1 этаже слева появились комнаты 2 этажа или демонолог")
	if left.has(&"history"):
		errors.append("история в оффере до демонолога")
	var right: Array[StringName] = RoomPool.offer_for(&"kabinet_4")
	if RoomPool.offer_for(&"kabinet_5") != right or RoomPool.offer_for(&"kabinet_6") != right:
		errors.append("все закрытые двери правого крыла 1 этажа должны показывать один драфт")
	if right.has(&"library"):
		errors.append("библиотека попала в оффер 1 этажа")
	if right.has(&"history"):
		errors.append("история в правом оффере до демонолога")
	var f2_left: Array[StringName] = RoomPool.offer_for(&"kabinet_7")
	if f2_left.size() != 2:
		errors.append("оффер 2 этажа слева должен быть из 2 кабинетов, было %d" % f2_left.size())
	if not f2_left.has(&"classroom") and not f2_left.has(&"cafeteria"):
		errors.append("в левом драфте 2 этажа нет ни кабинета, ни столовой")
	if RoomPool.offer_for(&"kabinet_8") != f2_left:
		errors.append("обе закрытые двери левого крыла 2 этажа должны показывать один драфт")
	if f2_left.has(&"demonologist") or f2_left.has(&"library"):
		errors.append("демонолог или библиотека попали в левое крыло 2 этажа")
	if f2_left.has(&"gym"):
		errors.append("спортзал в оффере до столовой")
	var f2_right: Array[StringName] = RoomPool.offer_for(&"kabinet_9")
	if RoomPool.offer_for(&"kabinet_10") != f2_right:
		errors.append("обе закрытые двери правого крыла 2 этажа должны показывать один драфт")
	if f2_right.has(&"gym"):
		errors.append("спортзал справа в оффере до столовой")
	var picked: StringName = left[0]
	if not RoomPool.commit(&"kabinet_1", picked):
		errors.append("не удалось зафиксировать выбор")
	var left_after: Array[StringName] = RoomPool.offer_for(&"kabinet_2")
	if left_after != RoomPool.offer_for(&"kabinet_3"):
		errors.append("после открытия двери оставшиеся двери крыла должны иметь один новый драфт")
	if not RoomPool.is_repeatable(picked) and left_after.has(picked):
		errors.append("выбранный кабинет снова попал в оффер крыла")
	if RoomPool.offer_for(&"kabinet_4") != right:
		errors.append("драфт правого крыла изменился от открытия левой двери")
	if RoomPool.offer_for(&"kabinet_7") != f2_left:
		errors.append("драфт 2 этажа изменился от открытия двери 1 этажа")
	RoomPool._reset_day()
	if RoomPool._eligible(RoomPool.Wing.F2_LEFT).has(&"gym") \
			or RoomPool._eligible(RoomPool.Wing.F2_RIGHT).has(&"gym"):
		errors.append("спортзал в пуле до столовой")
	if not RoomPool.commit(&"kabinet_7", &"cafeteria"):
		errors.append("столовая не взялась на 2 этаже")
	if not RoomPool._eligible(RoomPool.Wing.F2_LEFT).has(&"gym") \
			and not RoomPool._eligible(RoomPool.Wing.F2_RIGHT).has(&"gym"):
		errors.append("после столовой спортзал должен появиться в пуле 2 этажа")
	var f2_right_after: Array[StringName] = RoomPool.offer_for(&"kabinet_9")
	if f2_right_after.has(&"cafeteria"):
		errors.append("столовая осталась в драфте другого крыла")
	if not RoomPool.commit(&"kabinet_9", &"cafeteria"):
		errors.append("повтор столовой должен открыть пустую комнату")
	if not RoomPool.is_empty_room(&"kabinet_9"):
		errors.append("повтор уникальной комнаты должен дать пустой слот")
	if RoomPool.get_drawn(&"kabinet_7") != &"cafeteria":
		errors.append("первая столовая не должна сброситься")
	RoomPool._reset_day()
	if not RoomPool.commit(&"kabinet_5", &"classroom"):
		errors.append("обычный кабинет не взялся справа")
	if RoomPool._used.has(&"classroom"):
		errors.append("обычный кабинет не должен помечаться занятым")
	var right_after: Array[StringName] = RoomPool.offer_for(&"kabinet_6")
	if right_after.has(&"classroom") and not RoomPool.commit(&"kabinet_6", &"classroom"):
		errors.append("обычный кабинет был в новом драфте, но повторно не взялся")
	print("  OK  драфт из двух и цены")
	RoomPool._reset_day()


func _test_energy_gate(errors: Array) -> void:
	RoomPool._reset_day()
	var door: StreamingDoor = load(DOOR).instantiate()
	door.target_location_id = &"kabinet_1"
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
	var icon := door.get_node_or_null(^"EnergyIcon") as MeshInstance3D
	if icon == null or not icon.visible:
		errors.append("над входом в кабинет нет значка энергии")
	var offer: Array[StringName] = RoomPool.offer_for(&"kabinet_1")
	if offer.is_empty():
		errors.append("пустой оффер для kabinet_1")
		door.queue_free()
		anchor.queue_free()
		return
	var cheap: StringName = &""
	var expensive: StringName = &""
	for room_id in offer:
		if RoomPool.entry_cost(room_id) == 1:
			cheap = room_id
		if RoomPool.entry_cost(room_id) == 2:
			expensive = room_id
	var pick: StringName = cheap if cheap != &"" else offer[0]
	var cost: int = RoomPool.entry_cost(pick)
	EnergySystem.current_energy = 0
	if door.apply_choice(pick):
		errors.append("выбор прошёл без энергии")
	if EnergySystem.current_energy != 0:
		errors.append("энергия изменилась при отказе выбора")
	if icon == null or not icon.visible:
		errors.append("значок энергии пропал после отказа")
	EnergySystem.current_energy = cost
	if not door.apply_choice(pick):
		errors.append("выбор не прошёл при наличии энергии")
	if EnergySystem.current_energy != 0:
		errors.append("ожидали списание %d, осталось %d" % [cost, EnergySystem.current_energy])
	if icon and icon.visible:
		errors.append("значок энергии остался после открытия")
	if not LocationManager.is_loaded(&"kabinet_1"):
		errors.append("кабинет не отмечен открытым после оплаты")
	if anchor.get_node_or_null(^"RoomSign") == null:
		errors.append("после выбора нет 3D-вывески в якоре")
	if not door.apply_choice(pick):
		errors.append("повторное открытие не удалось")
	if EnergySystem.current_energy != 0:
		errors.append("энергия списалась повторно, осталось %d" % EnergySystem.current_energy)
	EnergySystem.current_energy = 0
	var failed: Array = [false]
	var on_fail := func(_amount: int) -> void: failed[0] = true
	EnergySystem.energy_spend_failed.connect(on_fail)
	if EnergySystem.try_spend(1) or not failed[0]:
		errors.append("нулевой запас должен давать неудачную трату")
	EnergySystem.energy_spend_failed.disconnect(on_fail)
	if expensive != &"":
		print("  OK  вход за энергию (в оффере был и вариант за 2)")
	else:
		print("  OK  вход в кабинет за энергию")
	door.queue_free()
	anchor.queue_free()
	LocationManager.reset_streamed()
	RoomPool._reset_day()
	await get_tree().process_frame


func _test_end_day_button(errors: Array) -> void:
	var hud: Node = load("res://scenes/ui/energy_hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	var button := hud.get_node_or_null(^"Root/TopRight/EndDayButton") as Button
	if button == null or button.text != "Ой всё":
		errors.append("нет кнопки «Ой всё» под сердцами энергии")
	else:
		print("  OK  кнопка завершения дня")
	var refill := hud.get_node_or_null(^"Root/TopRight/RefillEnergyButton") as Button
	if refill == null:
		errors.append("нет тестовой кнопки «Повысить энергию»")
	else:
		EnergySystem.current_energy = 1
		hud._on_refill_pressed()
		if EnergySystem.current_energy != EnergySystem.max_energy:
			errors.append("кнопка не восстановила весь пул")
		else:
			print("  OK  повысить энергию")
	hud.queue_free()
	await get_tree().process_frame
