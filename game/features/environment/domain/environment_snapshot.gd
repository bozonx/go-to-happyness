class_name EnvironmentSnapshot
extends RefCounted

## The one way to **read** the environment (`world_environment.md` §2).
##
## Before this, the settlement tick assembled a dozen values by hand and pushed
## them through two layers as a positional call into the sky controller; every
## new consumer — a citizen's clothing, an animal's winter variant, sound, crops,
## fog — had to assemble its own set, and a cutscene had no address at all to say
## "make it the 15th of March, 19:40, thunderstorm".
##
## So this is deliberately a wide record and not an interface: adding temperature
## or a season changes **no signature between the environment and a consumer**,
## only fields here. It is rebuilt once per frame and passed whole. That is cheap
## because almost everything in it is a pure function of time (§3), not the
## result of walking the world.

enum Precipitation { NONE, RAIN, SNOW }
enum Mode {
	## The environment's own rules roll the day — ordinary play.
	SIMULATED,
	## A value is being held by whoever set it — cutscene, arena, staged scene, lab.
	SCRIPTED,
}

# --- Calendar (§4) -------------------------------------------------------------
var minute_of_day := 480.0
var day_of_year := 120
var year := 1
var day_of_session := 1
var days_per_year := 365
var latitude := 54.0
var time_scale := 1.0
## Minutes since the session began, never wrapped. Continuous animation (cloud
## drift, star sphere, the lunar month) runs on this, so scrubbing or skipping
## time scrolls it rather than restarting it.
var elapsed_minutes := 0.0

# --- Season and climate (§5) ---------------------------------------------------
var climate: StringName = &"temperate"
## Caption for UI, scenario conditions and content selection — never a branch for
## rendering or for a rule that could read a number instead.
var season: StringName = &"spring"
var season_phase := 0.0
var growth_rate := 0.0
var snow_chance := 0.0

# --- Temperature (§6) ----------------------------------------------------------
## Temperature of the map at reference height, in degrees. One number, because
## there is exactly one weather on the map — local rain and a second temperature
## inside a zone are refused outright (§6, §20).
var temperature := 12.0
## The same air with the wind and the rain in it. Survival rules want this one;
## freezing and melting want `temperature`, because water does not feel wind.
var felt_temperature := 12.0
var lapse_rate := 0.035

# --- Daylight and celestial bodies (§11) ---------------------------------------
var daylight_hours := 12.0
var sunrise_minute := 360.0
var sunset_minute := 1080.0
## Sine of the sun's altitude: positive above the horizon. Everything about
## daylight grades on it.
var solar_height := 0.0
var solar_altitude_degrees := 0.0
var solar_azimuth_degrees := 0.0
var lunar_height := 0.0
var lunar_altitude_degrees := 0.0
var lunar_azimuth_degrees := 0.0
var lunar_phase_axis := 1.0

# --- Weather (§7–§10) ----------------------------------------------------------
var pattern: StringName = &"fair"
var pattern_name := ""
## The two independent axes (§8). Grey and haze come from `storm_influence` only;
## no amount of `cloud_cover` ever greys the sky.
var cloud_cover := 0.0
var storm_influence := 0.0
var cloud_phase := WeatherModel.CloudPhase.CLEAR
var cloud_seed := 0.0
var wind_vector := Vector2.ZERO
var wind_direction := 0.0
var wind_strength := 0.0
## Integrated wind, the stable animation coordinate for clouds, flags and waves.
var wind_displacement := Vector2.ZERO
var precipitation := Precipitation.NONE
var precipitation_intensity := 0.0
var precipitation_phase := WeatherModel.Phase.CLEAR

# --- Atmosphere (§12) ----------------------------------------------------------
## How far can be seen, in world units. Scene fog and aerial perspective are
## consumers of this number, never its source — and so are a shooter's target
## acquisition and a citizen's search radius, because "how far can you see" must
## have one answer for the whole game.
var visibility_range := 900.0

var mode := Mode.SIMULATED


func is_night() -> bool:
	return solar_height <= 0.0


func is_precipitating() -> bool:
	return precipitation != Precipitation.NONE and precipitation_intensity > 0.0


func is_snowing() -> bool:
	return precipitation == Precipitation.SNOW and precipitation_intensity > 0.0


## Temperature at a point, which is the map temperature plus the height term —
## the same function, not a second source of truth (§6).
func temperature_at(position: Vector3) -> float:
	return temperature - position.y * lapse_rate


## Whether snow can lie and water can freeze right now. Kept here so the surface
## and water layers ask the environment instead of each forming its own idea of
## whether it is winter (§13.3).
func is_freezing() -> bool:
	return temperature <= 0.0
