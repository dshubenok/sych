extends Node3D

class_name World

const Location = preload("res://scripts/world/location.gd")

@export var starting_location: NodePath
@export var starting_entry: StringName

var current_location: Location

func _ready():
	if starting_location != NodePath():
		var loc: Location = get_node_or_null(starting_location)
		if loc:
			enter_location(loc, starting_entry)

func enter_location(location: Location, entry_name: StringName = StringName()):
	current_location = location
	var entry: Node3D = location.get_entry_point(entry_name)
	if entry:
		# Переместим игрока, если он в сцене
		var player := get_tree().get_first_node_in_group("player")
		if player and player is Node3D:
			player.global_transform.origin = entry.global_transform.origin

func connect_locations(from_location: Location, to_location: Location):
	if from_location and to_location:
		from_location.neighbors[to_location.location_id] = true
