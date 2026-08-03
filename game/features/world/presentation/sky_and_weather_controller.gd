class_name SkyAndWeatherController
extends Node3D

const SUN_GLARE_OCCLUSION_DISTANCE := 96.0
const SUN_GLARE_OCCLUSION_MASK := 1 | 8
# How far past the frame edge the placed artifacts survive. They need the sun to be
# roughly on screen, so this stays tight.
const SUN_GLARE_EDGE_ALLOWANCE := 0.18
# The veil reaches much further. The gameplay camera looks down about fifty degrees,
# which puts the top of the frame below the horizon: the sun is off screen in the
# ordinary view, and a tight allowance meant the flare was simply never seen.
const SUN_GLARE_VEIL_ALLOWANCE := 0.95
# The artifacts bloom as the sun approaches the middle of the frame — looking at the
# sun should be what makes the flare open up.
const SUN_GLARE_AIM_RANGE := 0.70
const SUN_GLARE_AIM_FLOOR := 0.35
const SUN_GLARE_OCCLUSION_SAMPLE_RADIUS := 0.24
const CLOUD_SCALE := 1.55
# Wind vector arrives as a 0..1 bearing*strength from the weather model; this scales
# it into cloud-UV drift per game-minute. The shader then applies per-altitude speed
# multipliers on top (fast cirrus, slow cumulus).
const CLOUD_WIND_UV_SCALE := 0.0045
# Fallback wind used only when a caller passes no wind (calm-ish default drift).
const CLOUD_WIND_FALLBACK := Vector2(0.006, 0.002)
# Shape-morph rate per game-minute; a full day now produces one slow evolution
# cycle rather than several restless reshapes.
const CLOUD_EVOLVE_SCALE := 0.0007
const CLOUD_EDGE_SOFTNESS := 0.048
# Fair-weather coverage stays in a gapped range no matter how high cloud_cover goes,
# so raising cover only makes more/bigger cumulus — never a sealed grey sheet. The
# storm front owns the full ceiling separately (u_storm_amount in the shader).
const CLOUD_COVERAGE_MIN_CLOUDS := 0.60
const CLOUD_COVERAGE_MAX_CLOUDS := 0.24
const CLOUD_MINIMUM_SUN_VISIBILITY := 0.12
# Angular radii of the celestial discs, in radians. Both are far larger than the
# real half-degree: the style is painted anime realism, where the sun and the moon
# are compositional subjects rather than accurate points of light.
const SUN_ANGULAR_RADIUS := 0.046      # ~2.6 degrees
const MOON_ANGULAR_RADIUS := 0.062     # ~3.6 degrees, deliberately the larger body
# Both discs swell as they approach the horizon. This is the stylised "moon
# illusion": rises and sets become events instead of a dot crossing the sky.
const SUN_HORIZON_SWELL := 1.55
const MOON_HORIZON_SWELL := 1.85
# How high the body must climb before it settles at its base size.
const DISC_SWELL_ALTITUDE := 0.34
# The moon's arc, its rise time and its phase are computed by `SolarGeometry` from
# the calendar and arrive in the snapshot. Only the drawing of the disc is here.
# Phase axis range across the month: +1 is full, 0 half. It never reaches a new moon
# — the dark limb is a painterly cue here, so even the thinnest phase keeps most of
# the disc readable.
const MOON_PHASE_AXIS_MIN := -0.30
const MOON_PHASE_AXIS_MAX := 1.0
const MINUTES_PER_DAY := 1440.0
# Three-point sky palette. The gameplay camera looks down about fifty degrees, so the
# first twenty degrees above the horizon are what the player actually sees: the
# horizon and middle colours carry the frame, and the zenith caps the dome.
const SKY_DAY_HORIZON := Color("74cdee")
const SKY_DAY_MID := Color("3f9fe4")
const SKY_DAY_ZENITH := Color("1f63cf")
# Night deepens upward. The previous code blended the zenith toward the bright day
# blue at every hour, which left the night sky brighter overhead than at the horizon
# and drowned the stars in it.
const SKY_NIGHT_HORIZON := Color("1b2740")
const SKY_NIGHT_MID := Color("101a2b")
const SKY_NIGHT_ZENITH := Color("070c18")
# Twilight lilac, mixed into the middle band and barely into the zenith. The warm half
# of a dusk is painted around the sun by the shader; the rest of the dome stays cool,
# which is what gives the sky a direction at sunset.
const SKY_TWILIGHT_MID := Color("6d6ab0")
# Milky turquoise horizon haze. Mixing toward a lightened grey, as before, desaturated
# the one band of sky that is always on screen and is what made clear days read flat.
const HAZE_CLEAR_COLOR := Color("bfeef7")
# One turn of the celestial sphere per day, so the stars trace an arc across a night.
const STAR_ROTATION_PER_DAY := TAU
# Cool blue night key light. Low enough to stay a mood, high enough to cast the
# soft shadows that a moonlit night reads by.
const MOON_LIGHT_ENERGY := 0.17
const MOON_LIGHT_COLOR := Color("8fa8d8")
# How quickly the sun's cloud occlusion is allowed to move the world lighting. A
# cloud crossing the sun should dim the meadow over a beat, not snap it.
const SUN_VISIBILITY_SMOOTHING := 0.09

class CloudLayerMix:
	var cumulus := 0.0
	var cirrus := 0.0
	var elongated := 0.0
	var storm := 0.0


var camera: Camera3D
var sun: DirectionalLight3D
var world_environment: Environment
var sky_material: ShaderMaterial
var precipitation_effect: Node3D # PrecipitationEffect
var fireflies: Array = [] # Array of FirefliesEffect
var sun_glare_material: ShaderMaterial
var sun_glare_visibility := 0.0
var sun_glare_veil_visibility := 0.0
# Drives the slow rotation of the starburst arms. Read from the caller's clock so it
# freezes whenever game time does, like every other sky animation.
var _glare_clock := 0.0
var moon_light: DirectionalLight3D
# Last computed directions toward each body. Published so tools (and anything that
# wants to frame or point at the sky) read the same arc the sky itself is drawn from.
var current_sun_direction := Vector3.UP
var current_moon_direction := Vector3.UP
# How much of the sun the clouds leave, after smoothing. Published so tools can
# report it: "the light changes when the sun goes behind a cloud" is otherwise only
# checkable by eye.
var current_sun_visibility := 1.0
# Temporally smoothed cloud occlusion of the sun, so world lighting eases across a
# passing cumulus instead of flickering with the noise field.
var _sun_visibility_smoothed := 1.0

func setup(
	p_camera: Camera3D,
	p_sun: DirectionalLight3D,
	p_world_environment: Environment,
	p_sky_material: ShaderMaterial,
	p_precipitation_effect: Node3D,
	p_fireflies: Array,
	p_sun_glare_material: ShaderMaterial
) -> void:
	camera = p_camera
	sun = p_sun
	world_environment = p_world_environment
	sky_material = p_sky_material
	precipitation_effect = p_precipitation_effect
	fireflies = p_fireflies
	sun_glare_material = p_sun_glare_material


## Draws the sky the snapshot describes (`world_environment.md` §2, §11, §18).
##
## It takes **one** value and decides nothing about the weather. The old
## positional call with ten arguments is what made every new environment value —
## a season, a temperature, fog — a change to three signatures in two layers;
## adding a field to the snapshot now costs nothing here until this file wants to
## read it.
##
## `runtime_seconds` is real elapsed time and stays separate on purpose: star
## twinkle and the glare's own animation must not run at game-clock speed, where
## minutes pass tens of times faster than seconds.
func update_daylight(snapshot: EnvironmentSnapshot, runtime_seconds: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if sun == null or world_environment == null or snapshot == null:
		return
	var cloud_cover := snapshot.cloud_cover
	var storm_influence := snapshot.storm_influence
	var rain_intensity := snapshot.precipitation_intensity
	var cloud_pattern_seed := snapshot.cloud_seed
	var wind_vector := snapshot.wind_vector
	var wind_displacement := snapshot.wind_displacement
	var precipitation_type := snapshot.precipitation
	# The sun's arc comes from the day of year and the latitude, not from a fixed
	# sweep (§11). This is why winter reads visually at all: a low sun, a short
	# day and a southern sunrise are the same thing seen three ways.
	var solar_height := snapshot.solar_height
	var solar_intensity := smoothstep(0.0, 0.28, solar_height)
	var twilight := 1.0 - smoothstep(0.0, 0.28, absf(solar_height))
	var cloud_night := 1.0 - smoothstep(-0.25, 0.05, solar_height)
	# Two independent weather regulators drive everything else:
	#   cloud_cover      -> fair-weather cloudiness (keeps a blue, saturated sky)
	#   storm_influence  -> storm front (grey murk, darkening, rain)
	# "Murk" is the grey, flat, desaturating atmosphere. It belongs solely to the
	# storm front: no amount of fair-weather cloud coverage ever greys the sky.
	var storm := clampf(storm_influence, 0.0, 1.0)
	var murk := storm
	# Cloud motion runs on the calendar's continuous minute count, so scrubbing or
	# skipping time scrolls and morphs the clouds with it instead of restarting them.
	var motion_clock := snapshot.elapsed_minutes
	# Wind is authored by the shared weather model (bearing*strength, 0..1). Anything
	# else that reacts to wind reads the same source, so clouds agree with it.
	var wind := wind_vector
	var wind_offset: Vector2
	if wind_displacement != Vector2.ZERO:
		wind_offset = wind_displacement * CLOUD_WIND_UV_SCALE
	elif wind == Vector2.ZERO:
		wind = CLOUD_WIND_FALLBACK
		wind_offset = wind * motion_clock
	else:
		wind = wind * CLOUD_WIND_UV_SCALE
		wind_offset = wind * motion_clock
	var wind_direction := wind.normalized()
	# Slow shape-morph clock: cumulus swell and dissolve rather than only scrolling.
	var cloud_evolve := motion_clock * CLOUD_EVOLVE_SCALE
	var cloud_layers := _cloud_layer_mix(
		cloud_cover,
		storm_influence,
		cloud_pattern_seed,
		cloud_night,
		motion_clock
	)
	var night_color := Color("101a2b")
	var twilight_color := Color("c66b52")
	var night_twilight_color := Color("503149")
	var day_color := Color("6fa9d6")
	var overcast_color := Color("60707a")
	var base_background: Color
	if solar_height <= 0.0:
		base_background = night_color.lerp(night_twilight_color, twilight * 0.55)
	else:
		base_background = twilight_color.lerp(day_color, smoothstep(0.0, 0.42, solar_height))
	world_environment.background_color = base_background.lerp(overcast_color, murk)
	# The light is kept a little above the true altitude at the horizon: a
	# perfectly horizontal key light throws shadows the length of the board and
	# reads as a bug rather than as a sunset.
	var sun_elevation := maxf(snapshot.solar_altitude_degrees, 3.0)
	sun.rotation_degrees = Vector3(-sun_elevation, snapshot.solar_azimuth_degrees, 0.0)
	var sun_direction := sun.global_transform.basis.z.normalized()
	var cloud_sun_visibility := _cloud_sun_visibility(
		sun_direction,
		cloud_cover,
		wind_offset,
		cloud_layers,
		cloud_evolve
	)
	# The world lighting reads the smoothed occlusion so a cumulus crossing the sun
	# dims the meadow over a beat; the sky shader keeps the instantaneous value,
	# where the disc must be hidden exactly when the cloud covers it.
	_sun_visibility_smoothed = lerpf(
		_sun_visibility_smoothed,
		cloud_sun_visibility,
		SUN_VISIBILITY_SMOOTHING
	)
	var sun_occlusion := 1.0 - _sun_visibility_smoothed
	current_sun_visibility = _sun_visibility_smoothed
	# Warm key light survives past the moment the sun touches the horizon, which is
	# what makes dawn and dusk read as golden rather than simply switching off.
	var twilight_key := twilight * smoothstep(-0.16, 0.02, solar_height)
	var key_energy := maxf(solar_intensity, twilight_key * 0.6)
	# Fair clouds only dapple the sun; a storm front is what actually smothers it.
	var direct_light := key_energy * (1.0 - cloud_cover * 0.45) * (1.0 - murk) * _sun_visibility_smoothed
	# Golden hour drives the key deep amber; a cloud passing over the sun cools what
	# is left, because the ground is then lit by sky scatter rather than by the disc.
	var base_sun_color := Color("f08a5d").lerp(Color("fff2d1"), solar_intensity)
	base_sun_color = base_sun_color.lerp(Color("ff9448"), twilight_key * 0.55)
	base_sun_color = base_sun_color.lerp(Color("b9c8dd"), sun_occlusion * 0.45)
	sun.light_color = base_sun_color.lerp(Color("a8b8c0"), murk)
	sun.light_energy = lerpf(0.0, 1.2, direct_light)
	sun.shadow_enabled = direct_light > 0.05
	# Shadows soften as the sun goes behind a cloud instead of staying razor sharp
	# under a light that is no longer really there.
	sun.shadow_opacity = lerpf(1.0, 0.0, maxf(murk, sun_occlusion * 0.7))
	# Ambient answers the same occlusion from the other side: light the disc loses is
	# not gone, it is scattered. Overcast moments therefore go flatter and cooler,
	# not simply darker.
	var base_ambient_color := Color("4b5872").lerp(Color("d7ebef"), maxf(solar_intensity, twilight * 0.35))
	base_ambient_color = base_ambient_color.lerp(Color("ffb27a"), twilight * 0.42 * (1.0 - murk))
	base_ambient_color = base_ambient_color.lerp(Color("aebfd4"), sun_occlusion * solar_intensity * 0.5)
	var base_ambient_energy := lerpf(0.18, 0.65, maxf(solar_intensity, twilight * 0.3))
	base_ambient_energy += sun_occlusion * solar_intensity * 0.14
	# Ground light desaturates toward grey only under murk; a full white cloud sheet
	# still lifts overall ambient energy.
	world_environment.ambient_light_color = base_ambient_color.lerp(Color("8a9aa3"), murk)
	world_environment.ambient_light_energy = lerpf(base_ambient_energy, 0.78, cloud_cover * 0.6 + murk * 0.4)
	var night_factor := 1.0 - smoothstep(0.0, 0.28, solar_height)
	# Twilight is still bright after the sun reaches the horizon. Keep stars out
	# until the sun is meaningfully below it, then fade them in during dusk.
	var star_visibility := 1.0 - smoothstep(-0.42, -0.08, solar_height)
	# How dark the clouds paint. Asymmetric on purpose: just after sunset the sun
	# still rims the clouds warm, but by the pre-dawn deep twilight they must read
	# as dim night masses instead of daytime white.
	# The moon rides its own arc, twelve hours out of phase with the sun and with
	# the declination reversed, which is what makes a winter moon ride high across
	# a long night. Both the rise time and the lit fraction are functions of the
	# calendar (§11), so nothing about the moon is ever stored: the same day always
	# shows the same moon.
	var moon_phase_axis := clampf(
		snapshot.lunar_phase_axis, MOON_PHASE_AXIS_MIN, MOON_PHASE_AXIS_MAX)
	var moon_height := snapshot.lunar_height
	var moon_elevation := maxf(snapshot.lunar_altitude_degrees, 3.0)
	var moon_azimuth := snapshot.lunar_azimuth_degrees
	var moon_basis := Basis.from_euler(Vector3(deg_to_rad(-moon_elevation), deg_to_rad(moon_azimuth), 0.0))
	var moon_direction := moon_basis.z.normalized()
	# Discs swell toward the horizon. The same radii feed the sky shader and the
	# screen-space glare cut-out, so the two can never disagree.
	var sun_radius := SUN_ANGULAR_RADIUS * _horizon_swell(sun_direction.y, SUN_HORIZON_SWELL)
	var moon_radius := MOON_ANGULAR_RADIUS * _horizon_swell(moon_direction.y, MOON_HORIZON_SWELL)
	current_sun_direction = sun_direction
	current_moon_direction = moon_direction
	_update_moon_light(
		moon_elevation,
		moon_azimuth,
		moon_height,
		cloud_night,
		murk,
		moon_phase_axis
	)
	if sky_material != null:
		# How far the palette has crossed from night to day. The range straddles the
		# horizon so the sky is still half-lit at the moment the sun touches it.
		var sky_day := smoothstep(-0.20, 0.16, solar_height)
		var sky_horizon := SKY_NIGHT_HORIZON.lerp(SKY_DAY_HORIZON, sky_day)
		var sky_mid := SKY_NIGHT_MID.lerp(SKY_DAY_MID, sky_day)
		var sky_zenith := SKY_NIGHT_ZENITH.lerp(SKY_DAY_ZENITH, sky_day)
		sky_mid = sky_mid.lerp(SKY_TWILIGHT_MID, twilight * 0.30)
		sky_zenith = sky_zenith.lerp(SKY_TWILIGHT_MID, twilight * 0.12)
		# Only murk flattens the dome to grey; fair-weather cloud, however busy, leaves
		# the blue saturated.
		sky_horizon = sky_horizon.lerp(overcast_color, murk)
		sky_mid = sky_mid.lerp(overcast_color, murk)
		sky_zenith = sky_zenith.lerp(overcast_color.darkened(0.12), murk)
		sky_material.set_shader_parameter("u_horizon_color", sky_horizon)
		sky_material.set_shader_parameter("u_mid_color", sky_mid)
		sky_material.set_shader_parameter("u_zenith_color", sky_zenith)
		sky_material.set_shader_parameter("u_sun_color", sun.light_color)
		sky_material.set_shader_parameter("u_overcast", cloud_cover)
		sky_material.set_shader_parameter("u_murk", murk)
		sky_material.set_shader_parameter("u_solar_intensity", solar_intensity)
		sky_material.set_shader_parameter("u_sun_visibility", cloud_sun_visibility)
		sky_material.set_shader_parameter("u_sun_dir", sun_direction)
		sky_material.set_shader_parameter("u_sun_angular_radius", sun_radius)
		sky_material.set_shader_parameter("u_moon_angular_radius", moon_radius)
		# The disc is present whenever the sun is above the horizon, independent of how
		# much light it delivers. Tying it to solar_intensity, as before, erased the sun
		# during exactly the golden hour it should dominate.
		sky_material.set_shader_parameter(
			"u_sun_disc_visibility",
			smoothstep(-0.05, 0.03, solar_height)
		)
		# Scattering energy that outlives the direct-light curve, so halo and horizon
		# band stay alight while the sun rests on the horizon.
		sky_material.set_shader_parameter(
			"u_sky_light_energy",
			clampf(maxf(solar_intensity, twilight_key * 0.9), 0.0, 1.0)
		)
		sky_material.set_shader_parameter("u_time", motion_clock)
		sky_material.set_shader_parameter("u_cloud_evolve", cloud_evolve)
		sky_material.set_shader_parameter("u_cloud_scale", CLOUD_SCALE)
		sky_material.set_shader_parameter("u_wind_offset", wind_offset)
		sky_material.set_shader_parameter("u_wind_direction", wind_direction)
		sky_material.set_shader_parameter("u_edge_softness", CLOUD_EDGE_SOFTNESS)
		sky_material.set_shader_parameter("u_coverage_clear", CLOUD_COVERAGE_MIN_CLOUDS)
		sky_material.set_shader_parameter("u_coverage_storm", CLOUD_COVERAGE_MAX_CLOUDS)
		sky_material.set_shader_parameter("u_cumulus_amount", cloud_layers.cumulus)
		sky_material.set_shader_parameter("u_cirrus_amount", cloud_layers.cirrus)
		sky_material.set_shader_parameter("u_elongated_amount", cloud_layers.elongated)
		sky_material.set_shader_parameter("u_storm_amount", cloud_layers.storm)
		# Cloud cover desaturates the sunset much more slowly than the rest of the
		# sky: broken clouds should catch peach light instead of turning uniformly
		# grey as soon as the forecast passes fifty percent.
		var horizon_glow := Color("ff6a2a").lerp(Color("a8b8c0"), murk * 0.45)
		sky_material.set_shader_parameter("u_horizon_glow_color", horizon_glow)
		sky_material.set_shader_parameter("u_night_factor", cloud_night)
		# Anti-solar dusk bands (Earth's shadow, Belt of Venus). Present only while the
		# sun sits on the horizon, and scrubbed out by a storm front.
		sky_material.set_shader_parameter("u_twilight", twilight * (1.0 - murk))
		sky_material.set_shader_parameter("u_star_visibility", star_visibility)
		# The celestial sphere turns on the same continuous clock as everything else, so
		# scrubbing the time of day rotates the stars with it.
		sky_material.set_shader_parameter(
			"u_star_rotation",
			motion_clock / MINUTES_PER_DAY * STAR_ROTATION_PER_DAY
		)
		# Twinkle runs on real elapsed seconds, not on the game clock. Game minutes pass
		# tens of times faster than wall time, and driving the twinkle from them strobed
		# the whole star field several times a second.
		sky_material.set_shader_parameter("u_star_time", runtime_seconds)
		# Atmospheric horizon band. Two separate contributions:
		#   * clear-weather glow: a soft light band by day, warm at dawn/dusk, and
		#     fully absent at clear night (day_light -> 0) so the stars sit on clean
		#     deep blue with no grey dome.
		#   * storm murk: a grey haze that hangs any time of day, including night.
		var day_light := maxf(solar_intensity, twilight)
		# Chroma-preserving: the band lightens toward a milky turquoise rather than
		# toward grey, so the horizon reads as atmosphere instead of as a wash.
		var haze_day := sky_horizon.lerp(HAZE_CLEAR_COLOR, 0.72 * day_light)
		var haze_color := haze_day.lerp(Color("ff9a5c"), twilight * (1.0 - murk) * 0.7)
		haze_color = haze_color.lerp(overcast_color.darkened(0.1), murk * 0.8)
		# Half the previous clear-weather density: a hint of distance, not a veil. The
		# dawn/dusk term is cut too — at full strength it whitened the whole lower half
		# of a sunrise and buried the colour the sunrise is for.
		var clear_haze := (0.07 + twilight * 0.26) * day_light * (1.0 - murk * 0.6)
		var storm_haze := murk * 0.5
		var haze_strength := clampf(clear_haze + storm_haze, 0.0, 0.85)
		sky_material.set_shader_parameter("u_haze_color", haze_color)
		sky_material.set_shader_parameter("u_haze_strength", haze_strength)
		# Night moon, opposite the sun and fading in with the deepening twilight.
		sky_material.set_shader_parameter("u_moon_dir", moon_direction)
		sky_material.set_shader_parameter("u_moon_energy", cloud_night)
		sky_material.set_shader_parameter("u_moon_phase_axis", moon_phase_axis)
	if precipitation_effect != null:
		# The world's wind, not the cloud-UV drift `wind` was rescaled into above:
		# flakes are carried by the same wind the flags and the waves read (§9).
		precipitation_effect.set_precipitation(
			precipitation_type, rain_intensity, snapshot.wind_vector)
	_apply_atmosphere(snapshot)
	_glare_clock = motion_clock
	_update_sun_glare(direct_light, cloud_cover, sun_radius)
	var firefly_factor := night_factor * (1.0 - cloud_cover * 0.5)
	for ff in fireflies:
		if is_instance_valid(ff):
			ff.set_night_factor(firefly_factor)


## Scene fog reads the snapshot's visibility range — it does not decide it
## (`world_environment.md` §12). "How far can you see" must have exactly one
## answer for the whole game, or the render and the rules drift apart: a target
## the shooter's acquisition says is invisible must not be plainly on screen.
func _apply_atmosphere(snapshot: EnvironmentSnapshot) -> void:
	if world_environment == null:
		return
	var visibility := maxf(snapshot.visibility_range, 1.0)
	world_environment.fog_enabled = visibility < EnvironmentState.CLEAR_VISIBILITY * 0.85
	if not world_environment.fog_enabled:
		return
	# Godot's fog is exponential — transmittance is `exp(-density * z)` — so "can be
	# seen for `visibility` metres" means roughly five percent left at that range,
	# which is `3 / visibility`. The reciprocal alone reads as no fog at all: at a
	# visibility of two hundred metres it leaves two thirds of the light at the far
	# side of a settlement.
	world_environment.fog_density = clampf(3.0 / visibility, 0.0, 0.12)
	# Fog takes the colour of the sky it hangs under, so a foggy dawn is peach and a
	# foggy storm is grey without either being authored twice. The floor keeps a
	# night fog visible: unlit fog is indistinguishable from plain darkness, and the
	# real thing catches the moon.
	world_environment.fog_light_color = world_environment.background_color.lerp(
		Color("c9d4dc"), 0.55)
	world_environment.fog_sky_affect = 0.0


func _cloud_layer_mix(
	cloud_cover: float,
	storm_influence: float,
	cloud_pattern_seed: float,
	night_factor: float,
	clock: float
) -> CloudLayerMix:
	var result := CloudLayerMix.new()
	var ordinary_weather := 1.0 - clampf(storm_influence, 0.0, 1.0)
	# Each layer waxes and wanes on its own slow, non-periodic clock (layered value
	# noise over elapsed time), so the sky is a shifting blend of different layers in
	# different proportions rather than one looping pulse. Thin high layers appear at
	# a lower coverage than the heavy cumulus, so partly-cloudy skies read as a mix.
	var t := clock * 0.004
	var cumulus_drift := _drift(t, cloud_pattern_seed + 3.0, 1.0)
	var cirrus_drift := _drift(t, cloud_pattern_seed + 21.0, 0.62)
	var elongated_drift := _drift(t, cloud_pattern_seed + 47.0, 0.83)
	var cumulus_presence := smoothstep(0.06, 0.34, cloud_cover)
	var thin_presence := smoothstep(0.0, 0.22, cloud_cover)

	result.cumulus = cumulus_presence * lerpf(0.32, 1.0, cumulus_drift)
	result.cumulus *= lerpf(1.0, 0.22, storm_influence)
	result.cumulus = maxf(result.cumulus, smoothstep(0.5, 0.85, cloud_cover) * 0.7)

	# Cirrus streaks coexist with cumulus (like the reference sky) instead of
	# vanishing as cover rises. A storm front scrubs them out.
	result.cirrus = lerpf(0.2, 0.62, cirrus_drift) * thin_presence * ordinary_weather

	# Elongated mid-altitude ribbons carry most of the "partly cloudy" texture.
	result.elongated = (0.25 + smoothstep(0.05, 0.55, cloud_cover) * 0.75)
	result.elongated *= lerpf(0.3, 1.0, elongated_drift)
	result.elongated *= smoothstep(0.03, 0.4, cloud_cover) * lerpf(1.0, 0.3, storm_influence)
	result.elongated = clampf(result.elongated, 0.0, 1.0)

	result.storm = clampf(storm_influence, 0.0, 1.0)

	# Night simplifies to the big readable cumulus masses; the high-frequency thin
	# layers fade to almost nothing so they do not smear the star field.
	result.cumulus *= lerpf(1.0, 0.85, night_factor)
	result.cirrus *= lerpf(1.0, 0.06, night_factor)
	result.elongated *= lerpf(1.0, 0.1, night_factor)
	return result


func _drift(t: float, seed: float, freq: float) -> float:
	# Smooth, non-periodic 0..1 wander from layered value noise sampled along the
	# weather clock. Remapped so it uses most of the 0..1 range.
	var raw := _fbm(Vector2(t * freq + seed, seed * 1.7 + 4.0))
	return clampf((raw - 0.28) / 0.44, 0.0, 1.0)


func _cloud_sun_visibility(
	sun_direction: Vector3,
	cover: float,
	wind_offset: Vector2,
	cloud_layers: CloudLayerMix,
	cloud_evolve: float
) -> float:
	var horizon := sun_direction.y
	var projection_scale := maxf(horizon + 0.55, 0.55)
	var uv := Vector2(sun_direction.x, sun_direction.z) / projection_scale
	uv *= CLOUD_SCALE * 1.6
	# Match the shader's slow cumulus drift using integrated wind displacement.
	uv += wind_offset
	var tower_direction := (
		sun_direction
		+ Vector3(wind_offset.x * 0.12, 0.0, wind_offset.y * 0.12)
	).normalized()
	var cloud_field := maxf(
		_layered_cloud_field(uv, cover, cloud_evolve),
		_tower_cloud_field(tower_direction)
	)
	var coverage_curve := pow(cover, 0.55)
	var coverage := lerpf(CLOUD_COVERAGE_MIN_CLOUDS, CLOUD_COVERAGE_MAX_CLOUDS, coverage_curve)
	var cumulus_dissolve := pow(1.0 - cloud_layers.cumulus, 1.4)
	var shape_coverage := coverage + cumulus_dissolve * 0.22
	var density := smoothstep(shape_coverage, shape_coverage + CLOUD_EDGE_SOFTNESS, cloud_field)
	density *= smoothstep(0.0, 0.14, cloud_layers.cumulus)
	# Only a storm seals the sun away; fair coverage just dapples it.
	var ceiling_amount := smoothstep(0.08, 0.96, cloud_layers.storm) * 0.92
	var cloud_alpha := maxf(density, ceiling_amount) * smoothstep(0.08, 0.34, horizon)
	return lerpf(1.0, CLOUD_MINIMUM_SUN_VISIBILITY, cloud_alpha)


# A line-for-line mirror of cloud_field() in sky_clouds.gdshader. It has to stay a
# mirror: this is what decides whether a cloud is standing in front of the sun, and
# a copy that has drifted from the shader silently answers for a sky nobody sees.
func _cloud_field(uv: Vector2, cloud_evolve: float) -> float:
	var evolve := Vector2(cloud_evolve, cloud_evolve * 0.63)
	var q := Vector2(
		_fbm(uv * 0.68 + evolve),
		_fbm(uv * 0.68 + Vector2(5.2, 1.3) - evolve * 0.5)
	)
	var macro := _fbm(uv * 0.30 + q * 0.48)
	var large_billows := _cellular_billow(uv * 0.72 + q * 0.58)
	var medium_billows := _cellular_billow(uv * 1.18 + q * 0.92 + Vector2(3.7, 8.1))
	var detail := _fbm(uv * 2.45 + q * 1.28)
	var family := smoothstep(0.40, 0.66, macro)
	var body := (
		macro * 0.34
		+ large_billows * 0.44
		+ medium_billows * 0.16
		+ detail * 0.06
	)
	return body * lerpf(0.26, 1.0, family)


func _layered_cloud_field(uv: Vector2, overcast: float, cloud_evolve: float) -> float:
	var primary := _cloud_field(uv, cloud_evolve)
	var satellites := _cloud_field(uv * 1.62 + Vector2(7.4, -3.1), cloud_evolve)
	var satellite_cut := lerpf(0.20, 0.36, smoothstep(0.42, 0.88, overcast))
	return maxf(primary, satellites - satellite_cut)


func _tower_cloud_field(direction: Vector3) -> float:
	var height := maxf(direction.y, 0.0)
	var bearing := Vector2(direction.x, direction.z)
	bearing /= maxf(bearing.length(), 0.001)
	var family_seed := _fbm(bearing * 1.35 + Vector2(0.0, 4.0))
	var family := smoothstep(0.48, 0.67, family_seed)
	var crown_seed := _fbm(bearing * 2.1 + Vector2(5.0, 2.0))
	var crown_height := lerpf(0.20, 0.64, pow(crown_seed, 1.65))
	var base := smoothstep(0.015, 0.075, height)
	var crown := 1.0 - smoothstep(crown_height - 0.055, crown_height + 0.035, height)
	var along := bearing.dot(Vector2(0.82, 0.57).normalized())
	var across := bearing.dot(Vector2(-0.57, 0.82).normalized())
	var billows := _cellular_billow(Vector2(along * 3.15 + across * 0.72, height * 7.2) + Vector2(1.7, 9.4))
	var erosion := _fbm(Vector2(across * 5.4 + along, height * 9.0) + Vector2(12.0, 3.0))
	var body := 0.50 + billows * 0.31 + erosion * 0.12
	return family * base * crown * body


func _cellular_billow(p: Vector2) -> float:
	var cell := p.floor()
	var local := p - cell
	var nearest := 2.0
	for y in range(-1, 2):
		for x in range(-1, 2):
			var neighbour := Vector2(x, y)
			var sample_cell := cell + neighbour
			var point := Vector2(
				_hash21(sample_cell + Vector2(7.1, 3.7)),
				_hash21(sample_cell + Vector2(19.3, 11.8))
			)
			nearest = minf(nearest, (neighbour + point - local).length())
	return 1.0 - smoothstep(0.18, 0.78, nearest)


func _fbm(p: Vector2) -> float:
	var value := 0.0
	var amplitude := 0.5
	for _octave in range(4):
		value += amplitude * _value_noise(p)
		p *= 2.02
		amplitude *= 0.5
	return value


func _value_noise(p: Vector2) -> float:
	var cell := p.floor()
	var fraction := p - cell
	fraction = fraction * fraction * (Vector2.ONE * 3.0 - fraction * 2.0)
	var a := _hash21(cell)
	var b := _hash21(cell + Vector2(1.0, 0.0))
	var c := _hash21(cell + Vector2(0.0, 1.0))
	var d := _hash21(cell + Vector2.ONE)
	return lerpf(lerpf(a, b, fraction.x), lerpf(c, d, fraction.x), fraction.y)


func _hash21(p: Vector2) -> float:
	p = Vector2(_fract(p.x * 123.34), _fract(p.y * 345.45))
	p += Vector2.ONE * p.dot(p + Vector2.ONE * 34.345)
	return _fract(p.x * p.y)


func _fract(value: float) -> float:
	return value - floorf(value)


func _horizon_swell(height: float, swell: float) -> float:
	# Height is the body's y component, so it already is the sine of its altitude.
	# The curve is biased low: the growth should be obvious only in the last stretch
	# above the horizon, not across half the sky.
	var low := 1.0 - smoothstep(0.0, DISC_SWELL_ALTITUDE, maxf(height, 0.0))
	return lerpf(1.0, swell, pow(low, 1.6))


func _update_moon_light(
	elevation_degrees: float,
	azimuth_degrees: float,
	moon_height: float,
	night: float,
	murk: float,
	phase_axis: float
) -> void:
	if moon_light == null or not is_instance_valid(moon_light):
		moon_light = DirectionalLight3D.new()
		moon_light.name = "MoonLight"
		# Owned by the controller rather than by the scene, so both the game world and
		# the weather lab get moonlight from the one place that computes the arc.
		add_child(moon_light)
	moon_light.rotation_degrees = Vector3(-elevation_degrees, azimuth_degrees, 0.0)
	moon_light.light_color = MOON_LIGHT_COLOR
	# Deliberately blind to individual clouds. A night is dim enough already; dimming
	# it further every time a cumulus drifts past the moon reads as a bug, not weather.
	# The storm front still matters, because that is a sealed ceiling.
	var moon_up := smoothstep(-0.02, 0.16, moon_height)
	# A thinner moon lights the ground less, but never to nothing: the floor keeps
	# every night navigable.
	var phase_light := lerpf(0.6, 1.0, clampf(phase_axis * 0.5 + 0.5, 0.0, 1.0))
	var energy := MOON_LIGHT_ENERGY * night * moon_up * phase_light * lerpf(1.0, 0.35, murk)
	moon_light.light_energy = energy
	moon_light.shadow_enabled = energy > 0.035
	# Soft, partial shadows: moonlight is a wide, low-contrast source.
	moon_light.shadow_opacity = 0.55


func _update_sun_glare(direct_light: float, overcast: float, sun_angular_radius: float) -> void:
	if sun_glare_material == null or camera == null or sun == null:
		return
	var sun_direction := sun.global_transform.basis.z.normalized()
	var sun_position := camera.global_position + sun_direction * 1000.0
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or camera.is_position_behind(sun_position):
		sun_glare_visibility = lerpf(sun_glare_visibility, 0.0, 0.22)
		sun_glare_veil_visibility = lerpf(sun_glare_veil_visibility, 0.0, 0.22)
		sun_glare_material.set_shader_parameter("u_intensity", sun_glare_visibility)
		sun_glare_material.set_shader_parameter("u_veil_intensity", sun_glare_veil_visibility)
		return
	var screen_position := camera.unproject_position(sun_position)
	var raw_uv := Vector2(screen_position.x / viewport_size.x, screen_position.y / viewport_size.y)
	var outside_distance := maxf(maxf(-raw_uv.x, raw_uv.x - 1.0), maxf(-raw_uv.y, raw_uv.y - 1.0))
	var edge_fade := 1.0 - smoothstep(0.0, SUN_GLARE_EDGE_ALLOWANCE, outside_distance)
	var veil_fade := 1.0 - smoothstep(0.0, SUN_GLARE_VEIL_ALLOWANCE, outside_distance)
	var aspect := viewport_size.x / viewport_size.y
	# The veil needs the sun's true off-screen position, otherwise its gradient would
	# pour in from the nearest corner instead of from the direction the sun is in.
	# The clamp only protects against absurd values far outside the frame.
	var uv := raw_uv.clamp(Vector2(-3.0, -3.0), Vector2(4.0, 4.0))
	# How centred the sun is, in the same aspect-corrected units the shader uses.
	var aim_offset := (raw_uv - Vector2(0.5, 0.5)) * Vector2(aspect, 1.0)
	var aim := 1.0 - smoothstep(0.0, SUN_GLARE_AIM_RANGE, aim_offset.length())
	aim = lerpf(SUN_GLARE_AIM_FLOOR, 1.0, aim)
	var occlusion := _sun_glare_occlusion(sun_direction)
	var weather_visibility := direct_light * (1.0 - overcast * 0.9) * occlusion
	var target_visibility := weather_visibility * edge_fade * aim
	var target_veil := weather_visibility * veil_fade
	sun_glare_visibility = lerpf(sun_glare_visibility, target_visibility, 0.14)
	sun_glare_veil_visibility = lerpf(sun_glare_veil_visibility, target_veil, 0.14)
	sun_glare_material.set_shader_parameter("u_sun_screen_pos", uv)
	sun_glare_material.set_shader_parameter("u_aspect", aspect)
	# Project the disc's angular radius into the same aspect-corrected screen units the
	# glare works in (1.0 == viewport height), so the cut-out follows the sun as it
	# swells at the horizon and as the camera changes its field of view.
	var half_fov := deg_to_rad(camera.fov) * 0.5
	var disc_radius := tan(sun_angular_radius) / maxf(2.0 * tan(half_fov), 0.0001)
	sun_glare_material.set_shader_parameter("u_disc_radius", clampf(disc_radius, 0.002, 0.5))
	sun_glare_material.set_shader_parameter("u_sun_color", sun.light_color)
	sun_glare_material.set_shader_parameter("u_intensity", sun_glare_visibility)
	sun_glare_material.set_shader_parameter("u_veil_intensity", sun_glare_veil_visibility)
	sun_glare_material.set_shader_parameter("u_time", _glare_clock)


func _sun_glare_occlusion(sun_direction: Vector3) -> float:
	var world := get_world_3d()
	if world == null:
		return 1.0
	var right := camera.global_transform.basis.x.normalized() * SUN_GLARE_OCCLUSION_SAMPLE_RADIUS
	var up := camera.global_transform.basis.y.normalized() * SUN_GLARE_OCCLUSION_SAMPLE_RADIUS
	var sample_offsets: Array[Vector3] = [Vector3.ZERO, right, -right, up, -up]
	var clear_samples := 0
	for offset in sample_offsets:
		var from := camera.global_position + sun_direction * 0.75 + offset
		var query := PhysicsRayQueryParameters3D.create(from, from + sun_direction * SUN_GLARE_OCCLUSION_DISTANCE)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.collision_mask = SUN_GLARE_OCCLUSION_MASK
		if world.direct_space_state.intersect_ray(query).is_empty():
			clear_samples += 1
	return float(clear_samples) / float(sample_offsets.size())
