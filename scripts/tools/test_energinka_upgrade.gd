extends Node

## Банки в Шараге больше нет: +1 к максимуму даёт квест историка.
##   godot --headless --path . res://scenes/tools/test_energy_upgrade.tscn

func _ready() -> void:
	DaySystem.end_on_failed_spend = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: Array[String] = []
	EnergySystem.reset_progress()
	QuestSystem.reset_progress()

	var packed: PackedScene = load("res://scenes/locations/sharaga/sharaga.tscn")
	var sharaga: Node = packed.instantiate()
	add_child(sharaga)
	await get_tree().process_frame
	if sharaga.get_node_or_null(^"EnergyUpgradeCan") != null:
		errors.append("тестовая банка всё ещё стоит в Шараге")
	sharaga.queue_free()
	await get_tree().process_frame

	if EnergySystem.max_energy != 5 or EnergySystem.current_energy != 5:
		errors.append("старт не 5/5")
	if not EnergySystem.collect_upgrade(&"historian_quest"):
		errors.append("награда историка не применилась")
	if EnergySystem.max_energy != 6 or EnergySystem.current_energy != 6:
		errors.append("после историка ожидалось 6/6, было %d/%d" % [
			EnergySystem.current_energy, EnergySystem.max_energy])
	if EnergySystem.collect_upgrade(&"historian_quest"):
		errors.append("повтор награды не должен повышать запас")
	if EnergySystem.max_energy != 6:
		errors.append("повтор изменил максимум")
	EnergySystem.try_spend(2)
	EnergySystem.refill()
	if EnergySystem.current_energy != 6:
		errors.append("refill после апгрейда должен давать 6")

	EnergySystem.reset_progress()
	QuestSystem.reset_progress()
	for e in errors:
		print("  [ERROR] %s" % e)
	if errors.is_empty():
		print("[test_energy_upgrade] OK")
	else:
		print("[test_energy_upgrade] ПРОВАЛ — ошибок: %d" % errors.size())
	get_tree().quit(errors.size())
