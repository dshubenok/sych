extends Node

## Переход с трамваем (план демо §5, GDD §2 и §4):
##   godot --headless --path . res://scenes/tools/test_tram_transition.tscn
## Первый день: вводный текст и «Ладно», картинка зеркально, затем Шарага.
## Следующие дни: короткий переход без текста.

func _ready() -> void:
	DaySystem.end_on_failed_spend = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: Array[String] = []
	_speed_up()

	await _test_first_day(errors)
	await _test_later_day(errors)

	_speed_up()
	for e in errors:
		print("  [ERROR] %s" % e)
	if errors.is_empty():
		print("[test_tram_transition] OK")
	else:
		print("[test_tram_transition] ПРОВАЛ — ошибок: %d" % errors.size())
	get_tree().quit(errors.size())


func _speed_up() -> void:
	TramTransition.ride_seconds = 0.05
	TramTransition.tail_seconds = 0.05
	TramTransition.fade_seconds = 0.05
	TramTransition.short_seconds = 0.05
	TramTransition.text_fade_seconds = 0.02


func _test_first_day(errors: Array) -> void:
	DaySystem.day_number = 1
	var phases: Array[StringName] = []
	var on_phase := func(phase: StringName) -> void:
		phases.append(phase)
		if phase == &"button":
			if TramTransition._intro == null or TramTransition._intro.text != TramTransition.INTRO_TEXT:
				errors.append("вводный текст не совпадает с планом демо")
			if not TramTransition._intro.visible:
				errors.append("вводный текст не виден")
			if TramTransition._button == null or TramTransition._button.text != TramTransition.CONTINUE_TEXT:
				errors.append("нет кнопки «Ладно»")
			if TramTransition._image == null or not TramTransition._image.flip_h:
				errors.append("картинка трамвая не отражена зеркально")
			if TramTransition._music == null or TramTransition._music.stream == null:
				errors.append("нет музыки перехода")
			TramTransition.press_continue()
		if phase == &"tail":
			if TramTransition._intro.visible or TramTransition._button.visible:
				errors.append("после «Ладно» текст или кнопка остались на экране")
	TramTransition.phase_changed.connect(on_phase)
	await TramTransition.play(&"", &"")
	TramTransition.phase_changed.disconnect(on_phase)
	var expected: Array[StringName] = [&"ride", &"intro", &"button", &"tail", &"fade", &"arrive"]
	if phases != expected:
		errors.append("порядок первого дня: %s" % str(phases))
	else:
		print("  OK  первый день: текст, «Ладно», зеркало, музыка")


func _test_later_day(errors: Array) -> void:
	DaySystem.day_number = 2
	var phases: Array[StringName] = []
	var on_phase := func(phase: StringName) -> void:
		phases.append(phase)
	TramTransition.phase_changed.connect(on_phase)
	var container := Node3D.new()
	add_child(container)
	LocationManager.set_container(container)
	LocationManager.current_location_id = &"sychevalnya"
	var portal: LocationPortal = load("res://scenes/world/location_portal.tscn").instantiate()
	portal.auto_travel = false
	portal.target_location_id = &"sharaga"
	add_child(portal)
	await get_tree().process_frame
	portal._travel()
	var frames := 0
	while TramTransition.is_playing() and frames < 600:
		await get_tree().process_frame
		frames += 1
	TramTransition.phase_changed.disconnect(on_phase)
	if frames >= 600:
		errors.append("переход второго дня не закончился")
	if phases.has(&"intro") or phases.has(&"button"):
		errors.append("после первого дня снова показан вводный текст")
	if LocationManager.current_location_id != &"sharaga":
		errors.append("после перехода Сыч не в Шараге (%s)" % LocationManager.current_location_id)
	else:
		print("  OK  второй день: без текста, прибытие в Шарагу")
	portal.queue_free()
