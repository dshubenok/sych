extends Node3D

func _ready():
	print("=== ГЛАВНАЯ СЦЕНА ЗАГРУЖЕНА ===")
	print("Floor1 загружен: ", $Floor1 != null)
	print("Пол первого этажа (коллизия) есть: ", $Floor1/FirstFloorCollision != null)
	print("Игрок загружен: ", $Player != null)
	print("Камера игрока: ", $Player/Camera3D != null)
	print("Скрипт игрока: ", $Player.get_script() != null)
	# Установим позицию игрока в точку спавна
	var spawn := $Floor1/PlayerSpawn
	if spawn and $Player and $Player is Node3D:
		$Player.global_transform.origin = spawn.global_transform.origin
	print("=== ГОТОВ К ИГРЕ ===")
	print("Управление:")
	print("- WASD: движение")
	print("- Мышь: поворот камеры")
	print("- Space: прыжок")
	print("- Escape: освободить/захватить мышь")
