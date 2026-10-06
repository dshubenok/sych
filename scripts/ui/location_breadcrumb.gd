extends CanvasLayer

## Хлебные крошки текущей локации — мелким шрифтом сверху-слева.
## Обновляются по сигналу LocationManager.location_entered.
## В кабинетах из пула скрыты: имя комнаты только на 3D-вывеске.

@onready var _label: Label = $Label

func _ready() -> void:
	LocationManager.location_entered.connect(_on_location_entered)
	if LocationManager.current_location_id != &"":
		_apply(LocationManager.current_location_id)

func _on_location_entered(location_id: StringName) -> void:
	_apply(location_id)

func _apply(location_id: StringName) -> void:
	# Имя кабинета живёт только на 3D-вывеске в комнате.
	# Старый 2D-хлеб (крошки с «Демонолог» и т.п.) рядом с ней не показываем.
	if RoomPool.is_slot(location_id):
		_label.text = ""
		_label.visible = false
		return
	_label.visible = true
	_label.text = LocationRegistry.breadcrumb_text(location_id)
