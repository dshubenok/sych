extends Area3D
class_name PresenceZone

## Зона присутствия игрока. Сообщает LocationManager id локации —
## обновляются хлебные крошки и «текущая комната».

## Если задан — используем его, иначе ищем location_id у родителей.
@export var location_id: StringName = &""
## Куда вернуть игрока по крошкам, когда он вышел из этой зоны.
@export var exit_location_id: StringName = &""

func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_mask = 0xFFFFFFFF
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return
	var id := _resolved_id()
	if id != &"":
		LocationManager.notify_player_entered(id)

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group(&"player"):
		return
	if exit_location_id != &"":
		LocationManager.notify_player_entered(exit_location_id)

func _resolved_id() -> StringName:
	if location_id != &"":
		return location_id
	var n := get_parent()
	while n:
		var id = n.get("location_id")
		if id != null and id != &"":
			return id
		n = n.get_parent()
	return &""
