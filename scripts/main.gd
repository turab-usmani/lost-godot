extends Node3D

@export var player: Node3D
@export var spawn_radius: float = 30.0
@export var min_speed: float = 2.0
@export var max_speed: float = 12.0
@export var spawn_interval: float = 0.5

var active_hazards: Array[Dictionary] = []
var timer: float = 0.0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	# 1. Handle Spawning
	timer += delta
	if timer >= spawn_interval:
		timer = 0.0
		_spawn_noise_hazard()

	# 2. Handle Movement and Cleanup
	for i in range(active_hazards.size() - 1, -1, -1):
		var hazard_data = active_hazards[i]
		var area: Area3D = hazard_data["node"]

		if not is_instance_valid(area):
			active_hazards.remove_at(i)
			continue

		area.global_position += hazard_data["direction"] * hazard_data["speed"] * delta

		if area.global_position.distance_to(player.global_position) > spawn_radius * 1.5:
			area.queue_free()
			active_hazards.remove_at(i)

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

	# --- Generate the UNIQUE Noise Mesh ---
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _generate_asteroid_mesh()
	
	# === THE NEW SHADER MATERIAL ===
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = _get_vein_shader_code()
	mat.shader = shader
	
	# Pick a dark, charred base color for the rock
	var rock_color = Color(randf_range(0.05, 0.15), randf_range(0.05, 0.15), randf_range(0.05, 0.15))
	
	# Pick a random neon color for the glowing veins
	var neon_colors = [
		Color(0.9, 0.1, 0.1), # Red
		Color(0.1, 0.9, 0.2), # Green
		Color(0.1, 0.4, 1.0), # Blue
		Color(0.8, 0.1, 1.0), # Purple
		Color(1.0, 0.6, 0.1),  # Orange
		Color(0.748, 0.236, 0.247, 1.0)
	]
	var glow = neon_colors[randi() % neon_colors.size()]
	
	# Send the unique variables to the graphics card
	mat.set_shader_parameter("base_color", rock_color)
	mat.set_shader_parameter("glow_color", glow)
	# This massive random offset ensures every rock has a completely unique vein layout
	mat.set_shader_parameter("offset", Vector3(randf() * 100.0, randf() * 100.0, randf() * 100.0))
	
	mesh_instance.material_override = mat
	area.add_child(mesh_instance)

	# --- Add Collision ---
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0 
	collision.shape = shape
	area.add_child(collision)

	# --- Calculate Movement Variables ---
	var target_dir = (player.global_position - area.global_position).normalized()
	var speed = randf_range(min_speed, max_speed)

	active_hazards.append({
		"node": area,
		"direction": target_dir,
		"speed": speed
	})

# === THE MESH GENERATOR (From before) ===
func _generate_asteroid_mesh() -> ArrayMesh:
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = randf_range(0.02, 0.05) 
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED 
	
	var sphere = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 32 
	sphere.rings = 16

	var arrays = sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	
	for i in range(vertices.size()):
		var noise_val = noise.get_noise_3dv(vertices[i] * 10.0) 
		vertices[i] += normals[i] * noise_val * 0.4
		
	arrays[Mesh.ARRAY_VERTEX] = vertices
	
	var deformed_mesh = ArrayMesh.new()
	deformed_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var st = SurfaceTool.new()
	st.create_from(deformed_mesh, 0)
	st.generate_normals() 
	
	return st.commit()

# === THE GLOWING VEIN SHADER CODE ===
# We store the shader code as a string here so it doesn't require a separate file!
func _get_vein_shader_code() -> String:
	return """
	shader_type spatial;

	uniform vec3 base_color : source_color = vec3(0.1, 0.1, 0.1);
	uniform vec3 glow_color : source_color = vec3(0.0, 0.8, 1.0);
	uniform float glow_intensity = 6.0;
	uniform vec3 offset; 

	varying vec3 local_pos;

	void vertex() {
		// Capture the rock's 3D coordinates before camera movement 
		// so the veins stick to the rock and don't slide around
		local_pos = VERTEX;
	}

	// Mathematical magic to generate random 3D coordinates
	vec3 hash33(vec3 p) {
		p = fract(p * vec3(0.1031, 0.1030, 0.0973));
		p += dot(p, p.yxz + 33.33);
		return fract((p.xxy + p.yxx) * p.zyx);
	}

	void fragment() {
		// Multiply by 2.5 to scale how many veins appear. 
		vec3 p = local_pos * 2.5 + offset;
		
		vec3 n = floor(p);
		vec3 f = fract(p);

		float F1 = 8.0; // Nearest cell
		float F2 = 8.0; // Second nearest cell

		// Generate a 3D Voronoi Cellular pattern
		for (int k = -1; k <= 1; k++) {
			for (int j = -1; j <= 1; j++) {
				for (int i = -1; i <= 1; i++) {
					vec3 g = vec3(float(i), float(j), float(k));
					vec3 o = hash33(n + g);
					vec3 r = g - f + o;
					float d = dot(r, r);

					if (d < F1) {
						F2 = F1;
						F1 = d;
					} else if (d < F2) {
						F2 = d;
					}
				}
			}
		}

		// The "vein" is the border between cells.
		// By subtracting the nearest point from the second nearest, we find the edges.
		float edge = F2 - F1;
		
		// Invert it and sharpen it so we only get thin glowing lines
		float vein_mask = 1.0 - smoothstep(0.0, 0.15, edge);

		ALBEDO = base_color;
		// Multiply the neon color by the mask, then crank up the brightness
		EMISSION = glow_color * vein_mask * glow_intensity;
		ROUGHNESS = 0.9;
	}
	"""
