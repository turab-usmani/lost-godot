extends Node3D

@export var player: Node3D
@export var spawn_radius: float = 30.0
@export var min_speed: float = 0.5
@export var max_speed: float = 2.5
@export var spawn_interval: float = 0.5

var active_hazards: Array[Dictionary] = []
var timer: float = 0.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	timer += delta
	if timer >= spawn_interval:
		timer = 0.0
		_spawn_noise_hazard()

	for i in range(active_hazards.size() - 1, -1, -1):
		var hazard_data = active_hazards[i]
		var area: Area3D = hazard_data["node"]

		if not is_instance_valid(area):
			active_hazards.remove_at(i)
			continue

		# Slowly drift the direction over time for organic floating
		var drift_time = hazard_data["drift_time"] + delta
		hazard_data["drift_time"] = drift_time

		var wobble = Vector3(
			sin(drift_time * hazard_data["wobble_freq"].x + hazard_data["wobble_phase"].x),
			cos(drift_time * hazard_data["wobble_freq"].y + hazard_data["wobble_phase"].y),
			sin(drift_time * hazard_data["wobble_freq"].z + hazard_data["wobble_phase"].z)
		) * 0.3

		var current_dir = (hazard_data["direction"] + wobble).normalized()
		area.global_position += current_dir * hazard_data["speed"] * delta

		# Slow spin
		area.rotate(hazard_data["spin_axis"], hazard_data["spin_speed"] * delta)

		# Bounce off the invisible sphere boundary instead of despawning
		var dist = area.global_position.distance_to(player.global_position)
		if dist > spawn_radius * 1.2:
			hazard_data["direction"] = (player.global_position - area.global_position).normalized()


func _spawn_noise_hazard() -> void:
	var area = Area3D.new()
	add_child(area)

	var u = randf()
	var v = randf()
	var theta = u * 2.0 * PI
	var phi = acos(2.0 * v - 1.0)
	var sin_phi = sin(phi)
	var spawn_dir = Vector3(sin_phi * cos(theta), sin_phi * sin(theta), cos(phi))

	area.global_position = player.global_position + (spawn_dir * spawn_radius)

	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _generate_alien_mesh()

	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = _get_glow_shader_code()
	mat.shader = shader

	# Palette: deep space neons — these become the PRIMARY glow
	var palettes = [
		[Color(0.0, 0.8, 1.0),   Color(0.5, 0.0, 1.0)],   # Cyan / Violet
		[Color(1.0, 0.2, 0.6),   Color(1.0, 0.6, 0.0)],   # Hot pink / Amber
		[Color(0.1, 1.0, 0.5),   Color(0.0, 0.4, 1.0)],   # Mint / Electric blue
		[Color(0.8, 0.0, 1.0),   Color(0.2, 0.8, 1.0)],   # Purple / Ice
		[Color(1.0, 0.4, 0.0),   Color(1.0, 0.9, 0.1)],   # Fire / Yellow
	]
	var palette = palettes[randi() % palettes.size()]
	var color_a = palette[0]
	var color_b = palette[1]

	mat.set_shader_parameter("color_a", color_a)
	mat.set_shader_parameter("color_b", color_b)
	mat.set_shader_parameter("glow_intensity", randf_range(3.0, 7.0))
	mat.set_shader_parameter("noise_scale", randf_range(1.5, 4.0))
	mat.set_shader_parameter("time_offset", randf() * 100.0)
	mat.set_shader_parameter("pulse_speed", randf_range(0.4, 1.2))
	mat.set_shader_parameter("rim_power", randf_range(1.5, 3.5))

	mesh_instance.material_override = mat
	area.add_child(mesh_instance)

	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0
	collision.shape = shape
	area.add_child(collision)

	# Random initial float direction (no bias toward player)
	var rand_dir = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()

	active_hazards.append({
		"node": area,
		"direction": rand_dir,
		"speed": randf_range(min_speed, max_speed),
		"drift_time": randf() * 100.0,
		# Each axis wobbles at a different frequency for organic movement
		"wobble_freq": Vector3(randf_range(0.2, 0.6), randf_range(0.2, 0.6), randf_range(0.2, 0.6)),
		"wobble_phase": Vector3(randf() * TAU, randf() * TAU, randf() * TAU),
		"spin_axis": Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized(),
		"spin_speed": randf_range(0.1, 0.6),
	})


func _generate_alien_mesh() -> ArrayMesh:
	# Layer 1: large, sweeping distortion
	var noise_macro = FastNoiseLite.new()
	noise_macro.seed = randi()
	noise_macro.frequency = randf_range(0.08, 0.18)
	noise_macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_macro.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_macro.fractal_octaves = 4

	# Layer 2: fine, sharp surface detail
	var noise_detail = FastNoiseLite.new()
	noise_detail.seed = randi()
	noise_detail.frequency = randf_range(0.3, 0.7)
	noise_detail.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise_detail.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise_detail.fractal_octaves = 3

	# Vary base shape: not all spheres
	var base_scale = Vector3(
		randf_range(0.7, 1.4),
		randf_range(0.7, 1.4),
		randf_range(0.7, 1.4)
	)

	var sphere = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24

	var arrays = sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

	for i in range(vertices.size()):
		# Squash/stretch base shape
		vertices[i] *= base_scale

		var sample_pos = vertices[i] * 8.0
		var macro_val = noise_macro.get_noise_3dv(sample_pos)
		var detail_val = noise_detail.get_noise_3dv(sample_pos * 2.0)

		# Blend: macro gives big lumps, detail gives sharp ridges
		var combined = macro_val * 0.65 + detail_val * 0.35
		vertices[i] += normals[i] * combined * 0.55

	arrays[Mesh.ARRAY_VERTEX] = vertices

	var deformed_mesh = ArrayMesh.new()
	deformed_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var st = SurfaceTool.new()
	st.create_from(deformed_mesh, 0)
	st.generate_normals()
	return st.commit()


func _get_glow_shader_code() -> String:
	return """
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, ambient_light_disabled;

uniform vec3 color_a : source_color = vec3(0.0, 0.8, 1.0);
uniform vec3 color_b : source_color = vec3(0.5, 0.0, 1.0);
uniform float glow_intensity : hint_range(1.0, 10.0) = 5.0;
uniform float noise_scale : hint_range(0.5, 6.0) = 2.5;
uniform float time_offset = 0.0;
uniform float pulse_speed : hint_range(0.1, 3.0) = 0.7;
uniform float rim_power : hint_range(1.0, 5.0) = 2.5;

varying vec3 local_pos;
varying vec3 local_normal;

// Smooth 3D noise helpers
vec3 hash3(vec3 p) {
	p = fract(p * vec3(127.1, 311.7, 74.7));
	p += dot(p, p.yzx + 19.19);
	return fract((p.xxy + p.yzz) * p.zyx);
}

// Smooth value noise — more organic than Voronoi for a glowy feel
float smooth_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f); // smoothstep curve

	return mix(
		mix(mix(dot(hash3(i + vec3(0,0,0)), f - vec3(0,0,0)),
				dot(hash3(i + vec3(1,0,0)), f - vec3(1,0,0)), f.x),
			mix(dot(hash3(i + vec3(0,1,0)), f - vec3(0,1,0)),
				dot(hash3(i + vec3(1,1,0)), f - vec3(1,1,0)), f.x), f.y),
		mix(mix(dot(hash3(i + vec3(0,0,1)), f - vec3(0,0,1)),
				dot(hash3(i + vec3(1,0,1)), f - vec3(1,0,1)), f.x),
			mix(dot(hash3(i + vec3(0,1,1)), f - vec3(0,1,1)),
				dot(hash3(i + vec3(1,1,1)), f - vec3(1,1,1)), f.x), f.y), f.z
	) * 0.5 + 0.5;
}

// Layered FBM for rich swirling detail
float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * smooth_noise(p);
		p = p * 2.1 + vec3(1.7, 9.2, 3.4);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	float t = TIME * pulse_speed + time_offset;

	// Swirling animated noise on the surface
	vec3 p = local_pos * noise_scale;
	// Warp the noise input for extra turbulence
	vec3 warp = vec3(
		fbm(p + vec3(0.0, 0.0, t * 0.3)),
		fbm(p + vec3(5.2, 1.3, t * 0.2)),
		fbm(p + vec3(3.7, 8.1, t * 0.25))
	);
	float pattern = fbm(p + warp * 1.2);

	// Pulse the whole thing
	float pulse = sin(t + pattern * 4.0) * 0.5 + 0.5;
	pattern = mix(pattern, pattern * pulse, 0.4);

	// Blend between the two palette colors based on the swirl pattern
	vec3 surface_color = mix(color_a, color_b, pattern);

	// Rim / Fresnel glow — bright at edges, darker in center
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), rim_power);

	// Inner core: dim, just a hint of color
	float core_brightness = pattern * 0.3;
	// Rim: full glow
	float rim_brightness = fresnel * 1.5;

	vec3 final_emission = surface_color * (core_brightness + rim_brightness) * glow_intensity;

	ALBEDO = vec3(0.0); // No diffuse — pure emission object
	EMISSION = final_emission;
	ALPHA = clamp(core_brightness * 0.6 + fresnel * 0.85, 0.15, 1.0);
	ROUGHNESS = 1.0;
}
"""
