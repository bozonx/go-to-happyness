class_name EditorFillConventions
extends RefCounted

## Единые правила авторинга наполнения, общие для редактора зданий и редактора
## карт (`map_fill_mode.md` §9.1: «раскладка намеренно совпадает с редактором
## зданий там, где действие то же самое»).
##
## Здесь живёт всё, что раньше было продублировано двумя контроллерами с
## расхождениями: шаг поворота и смещения, цвета призрака и маркеров, вид
## предпросмотра и кольцевой маркер. Разница между редакторами обязана
## оставаться разницей правил размещения, а не разницей внешнего вида и шагов.

## Шаг быстрого поворота. Он один на оба редактора и намеренно НЕ берётся из
## ассета: автор не должен угадывать, почему одна бочка крутится по 15°, а
## другая по 45°. 15° делит и 90°, и 45°, и 360° — минимальный шаг, из которого
## собираются все ходовые углы.
const ROTATION_STEP_DEG := 15.0
## Шаг смещения по любой оси — один и тот же в спинах инспектора и в привязке.
const OFFSET_STEP := 0.25
const SCALE_STEP := 0.05
const SCALE_MIN := 0.05
const SCALE_MAX := 10.0

## Окно склейки истории: правки одного поля одного объекта, идущие подряд
## быстрее этого, становятся одним шагом undo (`map_fill_mode.md` §7.5).
const HISTORY_MERGE_MSEC := 700

## Цвета обратной связи. Призрак: можно / нельзя / можно, но автор скорее всего
## ошибся. Маркеры: что выбрано и что выберет клик.
const COLOR_GHOST_VALID := Color(0.45, 0.85, 1.0, 0.4)
const COLOR_GHOST_BLOCKED := Color(1.0, 0.3, 0.2, 0.5)
const COLOR_GHOST_WARNING := Color(1.0, 0.85, 0.2, 0.5)
const COLOR_SELECTION := Color(0.35, 0.95, 1.0, 0.85)
const COLOR_HOVER := Color(1.0, 0.8, 0.2, 0.9)


static func snap_offset(value: float) -> float:
	return snappedf(value, OFFSET_STEP)


static func snap_rotation(value: float) -> float:
	return fposmod(snappedf(value, ROTATION_STEP_DEG), 360.0)


static func rotated_by(current_deg: float, direction: int) -> float:
	return fposmod(current_deg + ROTATION_STEP_DEG * direction, 360.0)


static func make_ghost_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = COLOR_GHOST_VALID
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## Делает инстанс похожим на предпросмотр, а не на поставленный объект:
## полупрозрачные меши, погашенный свет и остановленные частицы. Без гашения
## света и частиц призрак освещал сцену и был неотличим от настоящего объекта —
## ровно та ошибка, которая жила в редакторе карт, пока предпросмотр был
## реализован там отдельно.
static func apply_preview_look(root: Node3D, material: StandardMaterial3D) -> void:
	var targets: Array[Node] = [root]
	targets.append_array(root.find_children("*", "", true, false))
	for node: Node in targets:
		if node is Light3D:
			(node as Light3D).visible = false
		elif node is GPUParticles3D:
			(node as GPUParticles3D).emitting = false
		elif node is CPUParticles3D:
			(node as CPUParticles3D).emitting = false
		elif node is MeshInstance3D:
			(node as MeshInstance3D).material_override = material
		elif node is Label3D:
			(node as Label3D).modulate = Color(0.6, 0.9, 1.0, 0.6)


## Кольцо под объектом: выделение и наведение рисуются одним и тем же знаком в
## обоих редакторах, отличаясь только цветом.
static func make_ring_marker(color: Color) -> MeshInstance3D:
	var marker := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.42
	torus.outer_radius = 0.5
	marker.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = material
	return marker
