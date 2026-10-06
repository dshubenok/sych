class_name SychScale
## Мировая единица: 1 сыч = рост игрока от ступней до макушки = 2 метра.
## Все персонажи и крупные объекты меряем в сычах относительно Сыча.
## Преподаватель / взрослый не может быть ниже 1 сыча — Сыч студент.

const HEIGHT_M := 2.0
const PLAYER_HEIGHT_SYCHS := 1.0
const ADULT_HEIGHT_SYCHS := 1.35


static func meters(sychs: float) -> float:
	return sychs * HEIGHT_M


static func quad_size(pixel_width: float, pixel_height: float, height_sychs: float) -> Vector2:
	var height_m := meters(height_sychs)
	if pixel_height <= 0.0:
		return Vector2(height_m * 0.5, height_m)
	return Vector2(height_m * pixel_width / pixel_height, height_m)
