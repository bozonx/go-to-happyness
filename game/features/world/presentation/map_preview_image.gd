class_name MapPreviewImage
extends RefCounted

## `preview.png` карты — вид доски сверху, нарисованный из данных
## (`map_editor.md` §4, `procedural_map_generation.md` §11.4).
##
## Рисуется из слоёв, а не снимком с камеры, и это решение, а не упрощение.
## Превью нужно ровно там, где картинки на экране нет: `tools/make_builtin_maps.gd`
## печёт встроенные карты headless, а генератор карт в лаборатории отдаёт
## документ, который никто не показывал. Снимок вьюпорта под dummy-рендером
## возвращает пустое изображение — то есть «то же, чем рисует игра» здесь значит
## «в половине случаев ничего».
##
## Цвет материала берётся у `TerrainMaterialLibrary.swatch_of` — там же, откуда
## его берёт настоящая поверхность. Второй палитры для миниатюр не заводится:
## разошлись бы они молча и заметно только на экране выбора карты.
##
## Что превью показывает: материал поверхности, высоту (затенением), воду с её
## глубиной, лёд и лаву, вырезы. Чего не показывает: объекты, здания и зоны —
## они меняются чаще карты, а превью пересобирается только при сохранении.

## Сторона картинки в пикселях. Меню масштабирует её под свою рамку, поэтому
## размер выбран как компромисс: 256² читается на любой доске и весит килобайты.
const SIZE := 256

## Насколько сильно перепад высоты между соседями осветляет и затемняет клетку.
## Без затенения карта выглядит плоской заливкой: материал на равнине и на склоне
## горы один и тот же, и рельеф — главное, что автор хочет узнать в миниатюре.
const SHADE_STRENGTH := 0.16
## Свет падает с северо-запада: это направление, при котором люди читают рельеф
## как выпуклый, а не вдавленный.
const LIGHT_DIRECTION := Vector2i(-1, -1)

const HOLE_COLOUR := Color(0.05, 0.05, 0.07)
const LAVA_COLOUR := Color(0.92, 0.36, 0.10)
const ICE_COLOUR := Color(0.82, 0.90, 0.96)
## Мелкая вода и глубокая — разные цвета: береговая линия в миниатюре читается
## только по градиенту, силуэт озера сам по себе её не показывает.
const SHALLOW_WATER := Color(0.32, 0.60, 0.72)
const DEEP_WATER := Color(0.10, 0.24, 0.46)
## На скольких ступенях глубины вода становится «глубокой» окончательно.
const DEEP_AT_STEPS := 6.0


## Картинка доски, или `null`, если рисовать нечего. Никогда не роняет
## сохранение: карта без превью — это карта без превью, а не отказ записи.
##
## Рисуется в разрешении ДОСКИ и растягивается до `SIZE`, а не считается по
## пикселю. Разница не косметическая: по пикселю выходило 65 536 обращений к
## слоям на каждое сохранение независимо от размера карты — 560 мс, из-за
## которых сквозной тест редактора перестал укладываться в свой бюджет. По
## клеткам их ровно столько, сколько клеток, и на маленькой доске это в
## шестьдесят раз меньше работы.
static func render(document: MapDocument) -> Image:
	if document == null or document.terrain == null:
		return null
	var terrain := document.terrain
	var board := terrain.board_cells
	if board <= 0:
		return null
	var water := document.water

	# Буфер целиком вместо `set_pixel`: вызов на пиксель — это и есть та цена,
	# которую платит любой попиксельный проход в GDScript.
	var pixels := PackedByteArray()
	pixels.resize(board * board * 3)
	var minimum := terrain.min_cell()
	var offset := 0
	for row in board:
		for column in board:
			# Клетки центрированы на начале координат, поэтому адрес считается от
			# `min_cell()`, а не от нуля: «0 <= cell < board_cells» — повторяющаяся
			# ошибка этого кода, и она выглядит правильной ровно до первой карты,
			# половина которой лежит западнее origin.
			var colour := _colour_of(terrain, water, minimum + Vector2i(column, row))
			pixels[offset] = int(clampf(colour.r, 0.0, 1.0) * 255.0)
			pixels[offset + 1] = int(clampf(colour.g, 0.0, 1.0) * 255.0)
			pixels[offset + 2] = int(clampf(colour.b, 0.0, 1.0) * 255.0)
			offset += 3
	var image := Image.create_from_data(board, board, false, Image.FORMAT_RGB8, pixels)
	# NEAREST: превью — это карта, а не фотография, и размытая граница воды в нём
	# читается хуже, чем честная ступенька.
	image.resize(SIZE, SIZE, Image.INTERPOLATE_NEAREST)
	return image


static func _colour_of(terrain: TerrainGrid, water: WaterGrid, cell: Vector2i) -> Color:
	if terrain.is_hole(cell):
		return HOLE_COLOUR
	var colour := TerrainMaterialLibrary.swatch_of(
		terrain.material_index_at(cell), terrain.variant_at(cell))
	# Снег — состояние в detail-байте, а не материал (`terrain_materials.md`), и
	# в миниатюре он важнее материала под ним: заснеженная карта обязана читаться
	# заснеженной.
	var snow := terrain.snow_depth_at(cell)
	if snow > 0:
		colour = colour.lerp(Color(0.94, 0.96, 1.0), clampf(float(snow) / 3.0, 0.0, 1.0))
	colour = _shaded(terrain, cell, colour)
	if water != null:
		colour = _with_water(terrain, water, cell, colour)
	return colour


## Затенение по перепаду к соседу со стороны света. Считается по хранимой высоте
## колонки, а не по угловым высотам: миниатюре хватает склона, а угловые высоты
## стоят девяти чтений на пиксель.
static func _shaded(terrain: TerrainGrid, cell: Vector2i, colour: Color) -> Color:
	var lit := cell + LIGHT_DIRECTION
	if not terrain.is_inside(lit):
		return colour
	var drop := terrain.height_of(cell) - terrain.height_of(lit)
	var shade := clampf(float(drop) * SHADE_STRENGTH, -0.45, 0.45)
	return colour.lerp(Color.WHITE if shade > 0.0 else Color.BLACK, absf(shade))


static func _with_water(
	terrain: TerrainGrid,
	water: WaterGrid,
	cell: Vector2i,
	ground: Color
) -> Color:
	if not water.is_wet(terrain, cell):
		return ground
	if water.is_lava(cell):
		return LAVA_COLOUR
	if water.is_frozen(cell):
		return ICE_COLOUR
	var depth := clampf(float(water.depth_steps_at(terrain, cell)) / DEEP_AT_STEPS, 0.0, 1.0)
	var surface := SHALLOW_WATER.lerp(DEEP_WATER, depth)
	# Дно просвечивает на мелководье и не просвечивает на глубине — то же, что
	# делает вода в игре, и то, что делает брод видимым бродом.
	return ground.lerp(surface, lerpf(0.55, 1.0, depth))
