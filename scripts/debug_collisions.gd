extends Node3D

# Скрипт для отображения коллизий в режиме отладки
# Нажмите F1 для включения/выключения визуализации коллизий

var collision_visualizers = []
var debug_mode = false

func _ready():
	print("Отладчик коллизий загружен. Нажмите F1 для переключения визуализации.")

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
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
	# Находим все StaticBody3D в библиотечной комнате
	var library_room = get_node("../LibraryRoom")
	if library_room:
		_show_collisions_recursive(library_room)

func hide_collisions():
	# Удаляем все визуализаторы коллизий
	for visualizer in collision_visualizers:
		if is_instance_valid(visualizer):
			visualizer.queue_free()
	collision_visualizers.clear()

func _show_collisions_recursive(node):
	for child in node.get_children():
		if child is StaticBody3D:
			_create_collision_visualizer(child)
		_show_collisions_recursive(child)

func _create_collision_visualizer(static_body):
	for child in static_body.get_children():
		if child is CollisionShape3D:
			var shape = child.shape
			if shape is BoxShape3D:
				var mesh_instance = MeshInstance3D.new()
				var box_mesh = BoxMesh.new()
				box_mesh.size = shape.size
				mesh_instance.mesh = box_mesh
				
				# Создаем полупрозрачный материал
				var material = StandardMaterial3D.new()
				material.albedo_color = Color(1, 0, 0, 0.3)  # Красный полупрозрачный
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mesh_instance.material_override = material
				
				# Копируем трансформацию
				mesh_instance.transform = child.global_transform
				mesh_instance.name = "CollisionVisualizer"
				
				add_child(mesh_instance)
				collision_visualizers.append(mesh_instance) 
