extends Node
## Глобальное состояние энергинок: пул энергинок текущего дня и его максимум.

signal energinka_changed(current: int, maximum: int)
signal energinka_spent(amount: int)
signal energinka_spend_failed(amount: int)
signal energinka_restored(amount: int)

@export var max_energinka: int = 5

var energinka_pool: int = 5
var _collected_upgrades: Dictionary = {}


func _ready() -> void:
	energinka_pool = clampi(energinka_pool, 0, max_energinka)
	energinka_changed.emit(energinka_pool, max_energinka)


func has_upgrade(id: StringName) -> bool:
	return id != &"" and _collected_upgrades.has(id)


## Увеличить максимум энергинок навсегда. Новая ячейка сразу полная.
func increase_max_energinka(amount: int = 1) -> void:
	if amount <= 0:
		return
	max_energinka += amount
	energinka_pool += amount
	energinka_changed.emit(energinka_pool, max_energinka)


## Одноразовый апгрейд пула. Повтор с тем же id ничего не делает.
func collect_upgrade(id: StringName, amount: int = 1) -> bool:
	if id == &"" or _collected_upgrades.has(id):
		return false
	_collected_upgrades[id] = true
	increase_max_energinka(amount)
	return true


func can_spend_energinka(amount: int) -> bool:
	return amount <= 0 or energinka_pool >= amount


## Потратить энергинку: уменьшить пул на стоимость действия.
func spend_energinka(amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_spend_energinka(amount):
		energinka_spend_failed.emit(amount)
		return false
	energinka_pool -= amount
	energinka_changed.emit(energinka_pool, max_energinka)
	energinka_spent.emit(amount)
	return true


## Получить энергинку: увеличить пул, не превышая максимум.
func gain_energinka(amount: int) -> void:
	if amount <= 0:
		return
	var before := energinka_pool
	energinka_pool = clampi(energinka_pool + amount, 0, max_energinka)
	energinka_changed.emit(energinka_pool, max_energinka)
	var gained := energinka_pool - before
	if gained > 0:
		energinka_restored.emit(gained)


func refill() -> void:
	energinka_pool = max_energinka
	energinka_changed.emit(energinka_pool, max_energinka)


func reset_progress() -> void:
	max_energinka = 5
	energinka_pool = 5
	_collected_upgrades.clear()
	energinka_changed.emit(energinka_pool, max_energinka)
