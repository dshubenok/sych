extends Node3D
class_name ModelCollisions

## Тримеш-коллизии для импортированной модели, с вырезом проёмов под двери
## и порталы той же локации, а также явных объёмов `CollisionCutout`.
## Крупные стены — это 1–2 треугольника на всю грань, поэтому пересекающие
## вырез грани subdivидятся, а куски внутри выреза отбрасываются.

const DOOR_HALF_WIDTH := 1.4
const DOOR_HEIGHT := 2.9
const DOOR_Y_MIN := 0.22
const DOOR_DEPTH := 1.6
const SUBDIV_DEPTH := 5

## Вырез в локальных координатах узла: трансформ + границы.
class Cutout:
	var inverse: Transform3D
	var box: AABB

	func _init(xf: Transform3D, bounds: AABB) -> void:
		inverse = xf.affine_inverse()
		box = bounds

	func contains(world: Vector3) -> bool:
		return box.has_point(inverse * world)

	func overlaps_tri(a: Vector3, b: Vector3, c: Vector3) -> bool:
		var la: Vector3 = inverse * a
		var lb: Vector3 = inverse * b
		var lc: Vector3 = inverse * c
		var mn := Vector3(minf(la.x, minf(lb.x, lc.x)), minf(la.y, minf(lb.y, lc.y)), minf(la.z, minf(lb.z, lc.z)))
		var mx := Vector3(maxf(la.x, maxf(lb.x, lc.x)), maxf(la.y, maxf(lb.y, lc.y)), maxf(la.z, maxf(lb.z, lc.z)))
		return AABB(mn, mx - mn).intersects(box)


func _ready() -> void:
	call_deferred("_build")


func _build() -> void:
	var cutouts: Array[Cutout] = []
	var loc := _owner_location()
	if loc:
		_collect_cutouts(loc, cutouts)
	_generate(self, cutouts)


func _owner_location() -> Node:
	var n := get_parent()
	while n:
		if n is Location:
			return n
		n = n.get_parent()
	return get_parent()


func _collect_cutouts(node: Node, acc: Array[Cutout]) -> void:
	for child in node.get_children():
		if child is StreamingDoor or child is LocationPortal:
			var door_box := AABB(
				Vector3(-DOOR_HALF_WIDTH, DOOR_Y_MIN, -DOOR_DEPTH),
				Vector3(DOOR_HALF_WIDTH * 2.0, DOOR_HEIGHT - DOOR_Y_MIN, DOOR_DEPTH * 2.0))
			acc.append(Cutout.new((child as Node3D).global_transform, door_box))
		elif child is CollisionCutout:
			var size: Vector3 = (child as CollisionCutout).size
			acc.append(Cutout.new((child as Node3D).global_transform, AABB(-size * 0.5, size)))
		_collect_cutouts(child, acc)


func _generate(node: Node, cutouts: Array[Cutout]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		_create_collision(node as MeshInstance3D, cutouts)
	for child in node.get_children():
		_generate(child, cutouts)


func _create_collision(mi: MeshInstance3D, cutouts: Array[Cutout]) -> void:
	var mesh: Mesh = mi.mesh
	var faces := PackedVector3Array()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		if indices != null and indices.size() >= 3:
			var i := 0
			while i + 2 < indices.size():
				_add_filtered_tri(faces, mi, cutouts,
					verts[indices[i]], verts[indices[i + 1]], verts[indices[i + 2]], 0)
				i += 3
		else:
			var i := 0
			while i + 2 < verts.size():
				_add_filtered_tri(faces, mi, cutouts, verts[i], verts[i + 1], verts[i + 2], 0)
				i += 3
	if faces.size() < 9:
		push_warning("[ModelCollisions] Нет треугольников для коллизии у %s" % mi.name)
		return
	# Толстая плита пола из тримеша затягивает капсулу внутрь объёма,
	# и CharacterBody3D перестаёт ехать по горизонтали. Для такой плиты
	# ставим выпуклый короб: верхняя грань — поверхность, по которой ходят.
	if _is_floor_slab(mi, faces):
		_add_box(mi, _aabb_of(faces))
		return
	var body := StaticBody3D.new()
	body.name = "%s_col" % mi.name
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	cs.shape = shape
	body.add_child(cs)
	mi.add_child(body)


func _is_floor_slab(mi: MeshInstance3D, faces: PackedVector3Array) -> bool:
	var bounds: AABB = mi.global_transform * _aabb_of(faces)
	var size := bounds.size
	if size.y <= 0.0 or size.y > 0.45:
		return false
	if size.x < 1.0 or size.z < 1.0:
		return false
	if size.y > size.x * 0.2 or size.y > size.z * 0.2:
		return false
	return true


func _aabb_of(faces: PackedVector3Array) -> AABB:
	var bounds := AABB(faces[0], Vector3.ZERO)
	for p in faces:
		bounds = bounds.expand(p)
	return bounds


func _add_box(mi: MeshInstance3D, bounds: AABB) -> void:
	var body := StaticBody3D.new()
	body.name = "%s_col" % mi.name
	var cs := CollisionShape3D.new()
	cs.name = "Shape"
	cs.position = bounds.get_center()
	var box := BoxShape3D.new()
	box.size = bounds.size
	cs.shape = box
	body.add_child(cs)
	mi.add_child(body)


func _add_filtered_tri(faces: PackedVector3Array, mi: MeshInstance3D,
		cutouts: Array[Cutout], a: Vector3, b: Vector3, c: Vector3, depth: int) -> void:
	var xf := mi.global_transform
	var wa := xf * a
	var wb := xf * b
	var wc := xf * c
	var cut := _overlapping_cutout(wa, wb, wc, cutouts)
	if cut == null:
		faces.append(a)
		faces.append(b)
		faces.append(c)
		return
	if cut.contains(wa) and cut.contains(wb) and cut.contains(wc):
		return
	if depth >= SUBDIV_DEPTH:
		if cut.overlaps_tri(wa, wb, wc):
			return
		faces.append(a)
		faces.append(b)
		faces.append(c)
		return
	var ab := (a + b) * 0.5
	var bc := (b + c) * 0.5
	var ca := (c + a) * 0.5
	_add_filtered_tri(faces, mi, cutouts, a, ab, ca, depth + 1)
	_add_filtered_tri(faces, mi, cutouts, ab, b, bc, depth + 1)
	_add_filtered_tri(faces, mi, cutouts, ca, bc, c, depth + 1)
	_add_filtered_tri(faces, mi, cutouts, ab, bc, ca, depth + 1)


func _overlapping_cutout(a: Vector3, b: Vector3, c: Vector3, cutouts: Array[Cutout]) -> Cutout:
	for cut in cutouts:
		if cut.overlaps_tri(a, b, c):
			return cut
	return null
