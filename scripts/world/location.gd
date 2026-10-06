extends Node3D
class_name Location

## Корень сцены конкретной локации.
## Хранит свой стабильный id и точки входа; родитель/иерархия живут в
## LocationRegistry, а переходы — в LocationManager.

@export var location_id: StringName
@export var display_name: String
@export var location_type: LocationTypes.Type = LocationTypes.Type.ROOM

## Точки входа (Marker3D). Сыч ставится в нужную при переходе.
## Если пусто — используется узел с именем "SychSpawn".
@export var entry_points: Array[NodePath] = []

func _ready() -> void:
	# Если имя не задано в сцене — берём из реестра (единый источник правды).
	if display_name.is_empty() and location_id != &"":
		var def := LocationRegistry.get_def(location_id)
		if def:
			display_name = def.title
			location_type = def.type

## Возвращает точку входа по имени. Пустое имя — точка по умолчанию.
func get_entry_point(point_name: StringName = &"") -> Node3D:
	if point_name != &"":
		for p in entry_points:
			var n := get_node_or_null(p)
			if n and n.name == String(point_name):
				return n as Node3D
		var by_name := get_node_or_null(NodePath(String(point_name)))
		if by_name is Node3D:
			return by_name
	# Точка по умолчанию: первый объявленный entry_point или "SychSpawn".
	if entry_points.size() > 0:
		var first := get_node_or_null(entry_points[0])
		if first is Node3D:
			return first
	var spawn := get_node_or_null(^"SychSpawn")
	if spawn is Node3D:
		return spawn
	return null
