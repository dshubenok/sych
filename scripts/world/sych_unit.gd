class_name SychUnit
## СЫЧ / сычовая единица (sych_unit): 1 СЫЧ = высота Сыча от ног до кончиков ушей = 2 м = 2 Godot units.
## Все персонажи и крупные объекты меряем в сычовых единицах относительно Сыча.
## Преподаватель / взрослый не может быть ниже 1 СЫЧа — Сыч студент.

const HEIGHT_M := 2.0
const SYCH_HEIGHT_SYCH_UNITS := 1.0
const ADULT_HEIGHT_SYCH_UNITS := 1.35


static func meters(sych_units: float) -> float:
	return sych_units * HEIGHT_M


static func quad_size(pixel_width: float, pixel_height: float, height_sych_units: float) -> Vector2:
	var height_m := meters(height_sych_units)
	if pixel_height <= 0.0:
		return Vector2(height_m * 0.5, height_m)
	return Vector2(height_m * pixel_width / pixel_height, height_m)
