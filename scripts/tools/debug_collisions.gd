extends Node3D

## Инструмент для визуализации коллизий. Нажмите F1, чтобы включить/выключить.

@export_node_path("Node3D") var collision_root_path: NodePath

var collision_root: Node3D
var collision_visualizers: Array[Node3D] = []
var debug_mode := false

func _ready():
	print("Отладчик коллизий загружен. Нажмите F1 для переключения визуализации.")
	if collision_root_path != NodePath():
		collision_root = get_node_or_null(collision_root_path)
	if collision_root == null:
		collision_root = get_parent()
	if collision_root == null:
		push_warning("DebugCollisions: не задан collision_root, ничего визуализировать.")

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		toggle_collision_debug()

func toggle_collision_debug():
	debug_mode = !debug_mode
	if debug_mode:
		show_collisions()
		print("Визуализация коллизий включена")
	else:
		hide_collisions()
		print("Визуализация коллизий выключена")

func show_collisions():
	if not collision_root:
		return
	_show_collisions_recursive(collision_root)

func hide_collisions():
	for visualizer in collision_visualizers:
		if is_instance_valid(visualizer):
			visualizer.queue_free()
	collision_visualizers.clear()

func _show_collisions_recursive(node: Node):
	for child in node.get_children():
		if child is CollisionObject3D:
			_create_collision_visualizer(child)
		_show_collisions_recursive(child)

func _create_collision_visualizer(static_body: CollisionObject3D):
	for child in static_body.get_children():
		if child is CollisionShape3D:
			var shape: Shape3D = child.shape
			if shape is BoxShape3D:
				var mesh_instance := MeshInstance3D.new()
				var box_mesh := BoxMesh.new()
				box_mesh.size = shape.size
				mesh_instance.mesh = box_mesh
				var material := StandardMaterial3D.new()
				material.albedo_color = Color(1, 0, 0, 0.3)
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh_instance.material_override = material
				mesh_instance.transform = child.global_transform
				mesh_instance.name = "CollisionVisualizer"
				add_child(mesh_instance)
				collision_visualizers.append(mesh_instance)
