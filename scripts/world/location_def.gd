extends Resource
class_name LocationDef

## Одна запись в реестре локаций — описывает узел иерархии.
## Источник правды по дереву хранится в LocationRegistry; сцены о своих
## родителях ничего не знают.

@export var id: StringName
@export var title: String
@export var parent_id: StringName
@export var type: LocationTypes.Type = LocationTypes.Type.ROOM
## Путь к сцене локации. Пусто — у логических узлов (например, «Мир»).
@export var scene_path: String = ""

func has_scene() -> bool:
	return not scene_path.is_empty()
