class_name SolarGeometry
extends RefCounted

## Where the sun and the moon are, from the day of year and the latitude
## (`world_environment.md` §11).
##
## Until now the sun walked the same arc in January and in July, which is why
## winter could not be read visually no matter how much snow was poured on the
## ground. Day length, noon altitude and the bearing of sunrise are all
## consequences of the calendar — that is precisely what `MapStart.latitude` was
## declared for.
##
## Everything here is a pure function of `(day_of_year, latitude, minute)`. No
## node, no shader, no wall clock (§3).

const MINUTES_PER_DAY := 1440.0
## Axial tilt. A world may want a different one later; it would become a climate
## field rather than a second copy of these formulas.
const AXIAL_TILT_DEGREES := 23.44
## The moon's arc is the sun's antipode with the tilt reversed, so a winter night
## carries a high moon exactly as a winter day carries a low sun.
const MOON_SYNODIC_DAYS := 29.53
const MOON_MAX_OFFSET_HOURS := 3.0


## Solar declination in radians. Day one is the start of the year, and the
## northern winter solstice sits ten days before it — the `+10` is that offset,
## scaled for worlds whose year is not 365 days long.
static func declination(day_of_year: int, days_per_year: int) -> float:
	var solstice_offset := 10.0 * float(days_per_year) / 365.0
	var phase := TAU * (float(day_of_year) + solstice_offset) / float(days_per_year)
	return -deg_to_rad(AXIAL_TILT_DEGREES) * cos(phase)


## Hour angle of the sun, zero at solar noon.
static func hour_angle(minute_of_day: float) -> float:
	return (fposmod(minute_of_day, MINUTES_PER_DAY) / MINUTES_PER_DAY) * TAU - PI


## Sine of the sun's altitude — the value everything about daylight is graded on.
## Positive means the disc is above the horizon.
static func solar_height(day_of_year: int, latitude: float, minute_of_day: float, days_per_year := 365) -> float:
	var dec := declination(day_of_year, days_per_year)
	var lat := deg_to_rad(clampf(latitude, -89.5, 89.5))
	var h := hour_angle(minute_of_day)
	return clampf(sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(h), -1.0, 1.0)


static func solar_altitude_degrees(day_of_year: int, latitude: float, minute_of_day: float, days_per_year := 365) -> float:
	return rad_to_deg(asin(solar_height(day_of_year, latitude, minute_of_day, days_per_year)))


## Bearing of the sun in the sky controller's convention: zero when the sun is
## due south (its noon position in the northern hemisphere), negative before
## noon. The old hard-coded `-75 … 11` sweep was an approximation of exactly
## this, valid for one latitude on one day.
static func solar_azimuth_degrees(day_of_year: int, latitude: float, minute_of_day: float, days_per_year := 365) -> float:
	var dec := declination(day_of_year, days_per_year)
	var lat := deg_to_rad(clampf(latitude, -89.5, 89.5))
	var h := hour_angle(minute_of_day)
	# Measured from due south, growing westward, which is what the renderer's
	# Y-rotation expects. atan2 keeps it continuous through the poles of the
	# formula, where a cos-based inversion would jump.
	var azimuth := atan2(sin(h), cos(h) * sin(lat) - tan(dec) * cos(lat))
	return rad_to_deg(azimuth)


## Length of the day in hours, `0` on a polar night and the whole day under a
## midnight sun. Both extremes fall straight out of the same formula, which is
## why a high-latitude map needs no special handling.
static func daylight_hours(day_of_year: int, latitude: float, days_per_year := 365) -> float:
	var dec := declination(day_of_year, days_per_year)
	var lat := deg_to_rad(clampf(latitude, -89.5, 89.5))
	var cos_hour_angle := -tan(lat) * tan(dec)
	if cos_hour_angle <= -1.0:
		return 24.0
	if cos_hour_angle >= 1.0:
		return 0.0
	return rad_to_deg(acos(cos_hour_angle)) * 2.0 / 15.0


static func sunrise_minute(day_of_year: int, latitude: float, days_per_year := 365) -> float:
	return 720.0 - daylight_hours(day_of_year, latitude, days_per_year) * 30.0


static func sunset_minute(day_of_year: int, latitude: float, days_per_year := 365) -> float:
	return 720.0 + daylight_hours(day_of_year, latitude, days_per_year) * 30.0


## How far through the synodic month the moon is, `0` at full. Read off the
## continuous clock, so nothing about the moon is ever stored: the same day
## always shows the same moon.
static func lunar_cycle(elapsed_minutes: float) -> float:
	return elapsed_minutes / (MINUTES_PER_DAY * MOON_SYNODIC_DAYS)


## A smooth month-long wander of the moon's rise time, kept inside a fraction of
## the night. A physically honest new moon would leave whole nights empty, which
## a cosy game has nothing to gain from.
static func lunar_offset_hours(elapsed_minutes: float) -> float:
	return sin(lunar_cycle(elapsed_minutes) * TAU) * MOON_MAX_OFFSET_HOURS


## The moon's altitude sine. Same machinery as the sun, twelve hours out of phase
## and with the declination reversed — which is what makes the winter moon ride
## high across a long night.
static func lunar_height(
	day_of_year: int,
	latitude: float,
	minute_of_day: float,
	elapsed_minutes: float,
	days_per_year := 365,
) -> float:
	var dec := -declination(day_of_year, days_per_year)
	var lat := deg_to_rad(clampf(latitude, -89.5, 89.5))
	var h := hour_angle(_lunar_minute(minute_of_day, elapsed_minutes))
	return clampf(sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(h), -1.0, 1.0)


static func lunar_altitude_degrees(
	day_of_year: int,
	latitude: float,
	minute_of_day: float,
	elapsed_minutes: float,
	days_per_year := 365,
) -> float:
	return rad_to_deg(asin(lunar_height(day_of_year, latitude, minute_of_day, elapsed_minutes, days_per_year)))


static func lunar_azimuth_degrees(
	day_of_year: int,
	latitude: float,
	minute_of_day: float,
	elapsed_minutes: float,
	days_per_year := 365,
) -> float:
	var dec := -declination(day_of_year, days_per_year)
	var lat := deg_to_rad(clampf(latitude, -89.5, 89.5))
	var h := hour_angle(_lunar_minute(minute_of_day, elapsed_minutes))
	return rad_to_deg(atan2(sin(h), cos(h) * sin(lat) - tan(dec) * cos(lat)))


## Lit fraction of the disc along the phase axis: `+1` full, `0` half. It never
## reaches a new moon — the dark limb is a painterly cue here, so even the
## thinnest phase keeps most of the disc readable.
static func lunar_phase_axis(elapsed_minutes: float, minimum := -0.30) -> float:
	return lerpf(minimum, 1.0, cos(lunar_cycle(elapsed_minutes) * TAU) * 0.5 + 0.5)


static func _lunar_minute(minute_of_day: float, elapsed_minutes: float) -> float:
	return minute_of_day + 720.0 + lunar_offset_hours(elapsed_minutes) * 60.0
