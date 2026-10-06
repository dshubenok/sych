extends Node3D

## Корневая «бутстрап»-сцена. Держит персистентные узлы (Сыч, камера, HUD,
## глобальные системы) и поручает загрузку самих локаций LocationManager.

const START_LOCATION := &"sychevalnya"

@onready var current_location: Node3D = $CurrentLocation
@onready var streamed_locations: Node3D = $StreamedLocations

func _ready():
	print("=== ГЛАВНАЯ СЦЕНА ЗАГРУЖЕНА ===")
	LocationManager.set_container(current_location)
	LocationManager.set_stream_container(streamed_locations)
	LocationManager.location_entered.connect(_on_location_entered)
	# Отложенно: на момент _ready корень сцены ещё «занят» настройкой детей.
	LocationManager.start_at.call_deferred(START_LOCATION)
	DaySystem.begin_day.call_deferred()
	print("Управление:")
	print("- WASD: движение")
	print("- Мышь: поворот камеры")
	print("- Space: прыжок")
	print("- Escape: меню")


## Escape открывает игровое меню поверх игры. Пока открыт другой модальный экран
## (комиксный диалог, выбор кабинетов, пробковая доска) — дерево уже на паузе, не мешаем.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_ESCAPE:
		return
	if MainMenu.is_open() or get_tree().paused or ComicDialogueSystem.is_active():
		return
	get_viewport().set_input_as_handled()
	MainMenu.open_game_menu(get_tree())

func _on_location_entered(location_id: StringName) -> void:
	print("=== ЛОКАЦИЯ: %s ===" % LocationRegistry.breadcrumb_text(location_id))
