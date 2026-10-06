extends Node

## Пока локация в дереве, вид зафиксирован на её камере.
## У Сычевальни угол не следует за игроком: камера смотрит в угол комнаты,
## как на концепте, а управление идёт относительно этого вида.

@export_node_path("Camera3D") var camera_path: NodePath
@export var priority: int = 20
## Точка, в которую смотрит камера, в координатах локации.
@export var look_at_local: Vector3 = Vector3(0.0, 1.35, 0.0)

var _manager: Node
var _sych: Node


func _ready() -> void:
	_aim_camera()
	_engage()


func _exit_tree() -> void:
	if _manager and is_instance_valid(_manager) and _manager.has_method("zone_exited"):
		_manager.zone_exited(self)
	if is_instance_valid(_sych) and _sych.has_method("clear_view_lock"):
		_sych.clear_view_lock(self)


func _aim_camera() -> void:
	var cam := get_node_or_null(camera_path) as Camera3D
	var host := get_parent() as Node3D
	if cam == null or host == null:
		return
	cam.look_at(host.to_global(look_at_local), Vector3.UP)


func _engage() -> void:
	var cam := get_node_or_null(camera_path) as Camera3D
	_manager = get_tree().get_first_node_in_group(&"camera_manager")
	_sych = get_tree().get_first_node_in_group(&"sych")
	if _manager and cam and _manager.has_method("zone_entered"):
		# snap: при пробуждении угол уже верный, без доворота из камеры игрока.
		_manager.zone_entered(self, cam, priority, false, true)
	if _sych and cam and _sych.has_method("set_view_lock"):
		_sych.set_view_lock(self, cam.global_transform.basis)
