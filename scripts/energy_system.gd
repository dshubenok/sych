extends Node
## Глобальное состояние энергии игрока.

signal energy_changed(current: int, maximum: int)
signal energy_spent(amount: int)
signal energy_spend_failed(amount: int)
signal energy_restored(amount: int)

@export var max_energy: int = 5

var current_energy: int = 5
var _collected_upgrades: Dictionary = {}


func _ready() -> void:
	current_energy = clampi(current_energy, 0, max_energy)
	energy_changed.emit(current_energy, max_energy)


func has_upgrade(id: StringName) -> bool:
	return id != &"" and _collected_upgrades.has(id)


## Увеличить максимум навсегда. Новая ячейка сразу полная.
func increase_max(amount: int = 1) -> void:
	if amount <= 0:
		return
	max_energy += amount
	current_energy += amount
	energy_changed.emit(current_energy, max_energy)


## Одноразовый апгрейд пула. Повтор с тем же id ничего не делает.
func collect_upgrade(id: StringName, amount: int = 1) -> bool:
	if id == &"" or _collected_upgrades.has(id):
		return false
	_collected_upgrades[id] = true
	increase_max(amount)
	return true


func can_spend(amount: int) -> bool:
	return amount <= 0 or current_energy >= amount


func try_spend(amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_spend(amount):
		energy_spend_failed.emit(amount)
		return false
	current_energy -= amount
	energy_changed.emit(current_energy, max_energy)
	energy_spent.emit(amount)
	return true


func restore(amount: int) -> void:
	if amount <= 0:
		return
	var before := current_energy
	current_energy = clampi(current_energy + amount, 0, max_energy)
	energy_changed.emit(current_energy, max_energy)
	var restored := current_energy - before
	if restored > 0:
		energy_restored.emit(restored)


func refill() -> void:
	current_energy = max_energy
	energy_changed.emit(current_energy, max_energy)


func reset_progress() -> void:
	max_energy = 5
	current_energy = 5
	_collected_upgrades.clear()
	energy_changed.emit(current_energy, max_energy)
