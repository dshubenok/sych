extends Node

## Банки в Шараге больше нет: +1 к максимуму энергинок даёт этап ветки Историка.
##   godot --headless --path . res://scenes/tools/test_energinka_upgrade.tscn

func _ready() -> void:
	DaySystem.end_on_failed_spend = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var errors: Array[String] = []
	EnerginkaSystem.reset_progress()
	BranchSystem.reset_progress()

	var packed: PackedScene = load("res://scenes/locations/sharaga/sharaga.tscn")
	var sharaga: Node = packed.instantiate()
	add_child(sharaga)
	await get_tree().process_frame
	if sharaga.get_node_or_null(^"EnerginkaUpgradeCan") != null:
		errors.append("тестовая банка всё ещё стоит в Шараге")
	sharaga.queue_free()
	await get_tree().process_frame

	if EnerginkaSystem.max_energinka != 5 or EnerginkaSystem.energinka_pool != 5:
		errors.append("старт не 5/5")
	if not EnerginkaSystem.collect_upgrade(&"historian_branch_stage"):
		errors.append("награда Историка не применилась")
	if EnerginkaSystem.max_energinka != 6 or EnerginkaSystem.energinka_pool != 6:
		errors.append("после Историка ожидалось 6/6, было %d/%d" % [
			EnerginkaSystem.energinka_pool, EnerginkaSystem.max_energinka])
	if EnerginkaSystem.collect_upgrade(&"historian_branch_stage"):
		errors.append("повтор награды не должен повышать пул")
	if EnerginkaSystem.max_energinka != 6:
		errors.append("повтор изменил максимум")
	EnerginkaSystem.spend_energinka(2)
	EnerginkaSystem.refill()
	if EnerginkaSystem.energinka_pool != 6:
		errors.append("refill после апгрейда должен давать 6")

	EnerginkaSystem.reset_progress()
	BranchSystem.reset_progress()
	for e in errors:
		print("  [ERROR] %s" % e)
	if errors.is_empty():
		print("[test_energinka_upgrade] OK")
	else:
		print("[test_energinka_upgrade] ПРОВАЛ — ошибок: %d" % errors.size())
	get_tree().quit(errors.size())
