class_name AmbientParticleEffect
extends AmbientEffect

## Атмосферный эффект из частиц, который реагирует на погоду
## (`map_fill_mode.md` §9.2.1, `world_environment.md`).
##
## Один владелец на три эффекта — дым из расщелины, брызги у порогов и пыльный
## вихрь — потому что различаются они не поведением, а числами: под каким
## условием эффект вообще идёт и как сильно его сносит ветром. Скрипт на каждый
## был бы тремя копиями одного цикла, расходящимися с первой же правкой.
##
## Всё, что нужно знать эффекту о мире, приходит в `EnvironmentSnapshot`. Ни
## часов, ни модели погоды он не читает: второй читатель разошёлся бы с первым в
## тот момент, когда директор начинает интерполировать.

## Условия, при которых эффект работает. Пустые значения означают «всегда» —
## дым из расщелины идёт в любую погоду, а вихрю нужны сушь и ветер.
@export var requires_dry := false
@export var requires_daylight := false
@export var min_wind_strength := 0.0
## Насколько сносит ветром: метры в секунду горизонтального ускорения на единицу
## силы ветра. У брызг ноль — их держит поток воды, а не воздух.
@export var wind_influence := 0.0
## Сколько секунд эффект набирает и теряет силу. Резко включённый столб дыма
## читается как ошибка отрисовки, а не как погода.
@export var fade_seconds := 2.5

var _emitters: Array[GPUParticles3D] = []
var _materials: Array[ParticleProcessMaterial] = []
var _base_gravity: Array[Vector3] = []
var _target := 1.0
var _strength := 0.0
## В редакторе эффект показывают вне зависимости от часа и погоды: автор,
## который не видит поставленное, не может поставить это хорошо.
var _authoring_preview := false


func _ready() -> void:
	super()
	for node: Node in find_children("*", "GPUParticles3D", true, false):
		var emitter := node as GPUParticles3D
		_emitters.append(emitter)
		# Материал дублируется на инстанс: иначе ветер, посчитанный для одной
		# расщелины, унёс бы дым всех остальных на карте.
		var material := emitter.process_material as ParticleProcessMaterial
		if material != null:
			material = material.duplicate() as ParticleProcessMaterial
			emitter.process_material = material
		_materials.append(material)
		_base_gravity.append(material.gravity if material != null else Vector3.ZERO)
	_strength = 1.0
	_apply_strength()


func apply_environment(snapshot: EnvironmentSnapshot) -> void:
	if snapshot == null:
		return
	_target = 0.0 if _is_suppressed(snapshot) else 1.0
	_apply_wind(snapshot.wind_vector * wind_influence)


func set_authoring_preview(enabled: bool) -> void:
	_authoring_preview = enabled
	if enabled:
		_target = 1.0
		_strength = 1.0
		_apply_strength()


func _is_suppressed(snapshot: EnvironmentSnapshot) -> bool:
	if _authoring_preview:
		return false
	if requires_dry and snapshot.is_precipitating():
		return true
	if requires_daylight and snapshot.is_night():
		return true
	return snapshot.wind_strength < min_wind_strength


func _process(delta: float) -> void:
	if is_equal_approx(_strength, _target):
		return
	var step := delta / maxf(fade_seconds, 0.01)
	_strength = move_toward(_strength, _target, step)
	_apply_strength()


## Гаснет эффект количеством частиц, а не `emitting = false`: выключенный
## эмиттер обрывает уже летящие частицы, и дым исчезает разом вместо того, чтобы
## рассеяться.
func _apply_strength() -> void:
	for emitter: GPUParticles3D in _emitters:
		emitter.amount_ratio = _strength
		emitter.emitting = _strength > 0.001


func _apply_wind(drift: Vector2) -> void:
	if is_zero_approx(wind_influence):
		return
	for index in _materials.size():
		var material := _materials[index]
		if material == null:
			continue
		material.gravity = _base_gravity[index] + Vector3(drift.x, 0.0, drift.y)
