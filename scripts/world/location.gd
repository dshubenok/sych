extends Node3D

class_name Location

@export var location_id: StringName
@export var location_title: String

## Точки входа/выхода для навигации между локациями
@export var entry_points: Array[NodePath] = []

## Соседние локации по дорожкам: key -> location_id
@export var neighbors: Dictionary = {}

func get_entry_point(point_name: StringName) -> Node3D:
	if point_name == StringName() and entry_points.size() > 0:
		return get_node_or_null(entry_points[0])
	for p in entry_points:
		var n := get_node_or_null(p)
		if n and n.name == String(point_name):
			return n
	return null
