class_name GerstnerOcean
extends MeshInstance3D

# This class should allow for the manipulation of the ocean:
# - Its displacements
# - Its automatic generation up to N waves
# - Adding, removing and clearing waves
# - Its visual enhancements
# - Adding, removing and clearing visual enhancements
# And there should be a GUI layer that interacts with these.

const _MAX_WAVES : int = 64

## List of waves
var waves : Array
## Number of waves
var waves_num : int
## Shader reference
var displacement_shader : ShaderMaterial
@export_group("Wave simulation parameters")
@export var number_of_waves : int = 32
@export var target_steepness : float = 3.0
@export var longest_wavelength : float = 60.0
@export var shortest_wavelength : float = 0.6
@export var amplitude_falloff : float = 1.4
@export var main_direction : Vector2 = Vector2(-0.55, 0.75)
@export var swell_spread_degrees: float = 25.0
@export var ripple_spread_degrees: float = 65.0
@export var seed_value: int = -1
@export_group("Visual parameters")
## Color of the ocean
@export var ocean_color : Color = Color(0.0, 0.25, 0.45)
## Shader parameters to enhance visuals
@export var show_domain_warping : bool = false
@export var show_lighting : bool = false
@export var show_foam : bool = false
@export var show_spray : bool = false
@export var noise_intensity : float = 0.2
# There is also a cool phenomenon called Fata Morgana
# that I'd like to include in the final version.

func _ready() -> void:
	# Initiate parameters
	waves = []
	waves_num = 0
	displacement_shader = material_override
	displacement_shader.set_shader_parameter("ocean_color", ocean_color)
	displacement_shader.set_shader_parameter("width", get_aabb().size.x)
	displacement_shader.set_shader_parameter("height", get_aabb().size.z)
	displacement_shader.set_shader_parameter("noise_intensity", noise_intensity)
	# ALERT: Missing a lot of initialization parameters
	# Create random waves and update the shader
	randomWaves(number_of_waves,target_steepness,longest_wavelength,shortest_wavelength,amplitude_falloff,main_direction,swell_spread_degrees,ripple_spread_degrees,seed_value)
	updateShader()
	return

# Add a new wave with the indicated parameters
func addWave(k : Vector2, A : float, phase : float) -> void:
	var new_wave : Array = [k,A,phase]
	waves.append(new_wave)
	waves_num += 1
	return

# Removes the last wave
func removeLastWave() -> void:
	waves_num -= 1
	waves.pop_back()
	return

# Update the number of waves
func updateWaves() -> void:
	waves_num = len(waves)
	return

# This function removes all the waves
func removeWaves() -> void:
	waves.clear()
	waves_num = 0
	return

# This function initializes the mesh with a Brownian motion - intensity here is the
# percentage of loss of strength of the amplitudes as frequencies increase.
# ALERT: It's the first version. The new version is below.
#func randomWaves(_now: int, intensity: float = 0.8) -> void:
	#var _waves : Array[Array]
	#var A: float
	#var k: Vector2
	#var phase: float
	#var angle : float
	#var direction : Vector2
	## Starting scale.
	#var new_magnitude: float = 0.2
	#var new_amplitude: float = 1.5
	## Random directions around a prevailing direction.
	#var main_angle: float = Vector2(-0.55, 0.75).angle()
	#var spread: float = deg_to_rad(40.0)
	#var rng := RandomNumberGenerator.new()
	#rng.randomize()
	## How the scale changes between successive waves.
	#var frequency_multiplier: float = 2-intensity
	#var amplitude_multiplier: float = intensity
	#for i in range(_now):
		#angle = main_angle + rng.randf_range(-spread, spread)
		#direction = Vector2(cos(angle), sin(angle))
		#A = new_amplitude * rng.randf_range(0.85, 1.15)
		#phase = rng.randf_range(0.0, TAU)
		#k = direction * new_magnitude * rng.randf_range(0.9, 1.1)
		#_waves.append([k[0], k[1], A, phase])
		#new_magnitude *= frequency_multiplier
		#new_amplitude *= amplitude_multiplier
	#
	#waves_num = _now
	#waves = _waves
	#return

# This function generates random waves according to a "more realistic" distribution.
func randomWaves(_now: int,_ts: float = 0.9,_lw: float = 50.0,_sw: float = 0.6,_af: float = 1.2,_md: Vector2 = Vector2(-0.55, 0.75),_ssd: float = 12.0,_rsd: float = 60.0,_s: int = -1) -> void:
	# Match the capacity declared in your shader.
	if _now < 0 or _now > _MAX_WAVES:
		push_error("Wave count must be between 0 and %d." % _MAX_WAVES)
		return
	if _now == 0:
		waves = []
		waves_num = 0
		return
	if _sw <= 0.0 or _lw < _sw:
		push_error("Require 0 < _sw <= _lw.")
		return
	if _ts < 0.0 or _af < 0.0:
		push_error("Steepness and amplitude falloff must be nonnegative.")
		return
	if _md.length_squared() == 0.0:
		push_error("The main wave direction cannot be zero.")
		return
	if _ssd < 0.0 or _rsd < 0.0:
		push_error("Directional spreads must be nonnegative.")
		return
	var rng := RandomNumberGenerator.new()
	if _s < 0:
		rng.randomize()
	else:
		rng.seed = _s
	var generated: Array[Array] = []
	var k_min: float = TAU / _lw
	var k_max: float = TAU / _sw
	var main_angle: float = _md.angle()
	var raw_steepness: float = 0.0
	for i in range(_now):
		# One random sample in each logarithmic frequency interval.
		# t = 0 corresponds to long swells; t = 1 to short waves.
		var t: float = (float(i) + rng.randf()) / float(_now)
		var magnitude: float = exp(lerpf(log(k_min), log(k_max), t))
		# Broaden the directional distribution toward shorter waves.
		var spread: float = deg_to_rad(lerpf(_ssd, _rsd, t))
		# A clipped Gaussian: directions cluster around the main angle.
		var offset: float = clampf(
			rng.randfn(0.0, 1.0) * spread * 0.5,-spread, spread)
		var angle: float = main_angle + offset
		var k: Vector2 = Vector2(cos(angle), sin(angle)) * magnitude
		# Relative amplitude envelope, normalized after generation.
		var A: float = pow(magnitude / k_min, -_af)
		A *= rng.randf_range(0.85, 1.15)
		var phase: float = rng.randf_range(0.0, TAU)
		generated.append([k.x, k.y, A, phase])
		raw_steepness += A * magnitude
	if raw_steepness <= 0.0:
		push_error("Amplitude weights are too small; reduce _af.")
		return
	# Preserve the requested total steepness.
	var amplitude_scale: float = _ts / raw_steepness
	for wave in generated:
		wave[2] = float(wave[2]) * amplitude_scale
	waves = generated
	waves_num = generated.size()
	return

# Update the shader variables
func updateShader() -> void:
	# Adjust visual parameters
	displacement_shader.set_shader_parameter("ocean_color", ocean_color)
	displacement_shader.set_shader_parameter("show_lighting", show_lighting)
	displacement_shader.set_shader_parameter("show_foam", show_foam)
	displacement_shader.set_shader_parameter("show_spray", show_spray)
	displacement_shader.set_shader_parameter("show_domain_warping", show_domain_warping)
	# Sync waves
	displacement_shader.set_shader_parameter("waves", waves)
	displacement_shader.set_shader_parameter("waves_num", waves_num)
	return
