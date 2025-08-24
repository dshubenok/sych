extends Node3D

func _ready():
	print("=== ГЛАВНАЯ СЦЕНА ЗАГРУЖЕНА ===")
	print("Библиотечная комната загружена: ", $LibraryRoom != null)
	print("3D модель библиотеки: ", $LibraryRoom/LibraryModel != null)
	print("Коллизия пола: ", $LibraryRoom/FloorCollision != null)
	print("Стены библиотеки: ", $LibraryRoom/WallNorth != null and $LibraryRoom/WallSouth != null and $LibraryRoom/WallEast != null and $LibraryRoom/WallWest != null)
	print("Мебель с коллизиями: ", $LibraryRoom/Bookshelf1 != null and $LibraryRoom/Table1 != null and $LibraryRoom/CenterTable != null)
	print("Игрок загружен: ", $Player != null)
	print("Камера игрока: ", $Player/Camera3D != null)
	print("Скрипт игрока: ", $Player.get_script() != null)
	print("=== ГОТОВ К ИГРЕ ===")
	print("Управление:")
	print("- WASD: движение")
	print("- Мышь: поворот камеры")
	print("- Space: прыжок")
	print("- Escape: освободить/захватить мышь")
