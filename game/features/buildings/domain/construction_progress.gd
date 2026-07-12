class_name ConstructionProgress
extends RefCounted

static func advance(progress: float, delta: float, duration: float, builder_power: float) -> float:
	if duration <= 0.0:
		return 1.0
	return minf(1.0, progress + delta / duration * maxf(0.0, builder_power))
