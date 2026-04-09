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

	# --- Calculate a random point on a sphere around the player ---
	var u = randf()
	var v = randf()
	var theta = u * 2.0 * PI
	var phi = acos(2.0 * v - 1.0)
	var sin_phi = sin(phi)
	var spawn_dir = Vector3(sin_phi * cos(theta), sin_phi * sin(theta), cos(phi))
	
	area.global_position = player.global_position + (spawn_dir * spawn_radius)

	# --- Generate the UNIQUE Noise Mesh ---
	var mesh_instance = MeshInstance3D.new()
	
	# Call our new function to build the physical potato shape
	mesh_instance.mesh = _generate_asteroid_mesh()
	
	# Apply a random rocky material color
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(randf_range(0.3, 0.6), randf_range(0.3, 0.6), randf_range(0.3, 0.6))
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	
	area.add_child(mesh_instance)

	# --- Add Collision ---
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0 # Adjusted to match the new mesh size
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

# === THE NEW MESH GENERATOR ===
# Placed at the bottom of your script so _spawn_noise_hazard can use it
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
