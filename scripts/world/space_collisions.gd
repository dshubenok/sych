extends Node3D

## Автоматически генерирует коллизии для всех мешей в модели
func _ready():
	# Находим модель SpaceModel
	var space_model = get_node_or_null("SpaceModel")
	if not space_model:
		print("SpaceModel не найден!")
		return
	
	# Рекурсивно находим все MeshInstance3D в модели и создаём для них коллизии
	_generate_collisions_for_node(space_model)
	
	print("Коллизии для стен сгенерированы!")

func _generate_collisions_for_node(node: Node):
	# Если это MeshInstance3D, создаём коллизию
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		var mesh = mesh_instance.mesh
		
		if mesh != null:
			# Используем встроенную функцию для создания тримеш-коллизий
			# Это создаст StaticBody3D с ConcavePolygonShape3D автоматически
			mesh_instance.create_trimesh_collision()
	
	# Рекурсивно обрабатываем дочерние узлы
	for child in node.get_children():
		_generate_collisions_for_node(child)

