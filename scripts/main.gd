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
	# Iterate backwards so we can safely remove elements while looping
	for i in range(active_hazards.size() - 1, -1, -1):
		var hazard_data = active_hazards[i]
		var area: Area3D = hazard_data["node"]

		# If the node was destroyed elsewhere, clean up the array
		if not is_instance_valid(area):
			active_hazards.remove_at(i)
			continue

		# Move the Area3D along its calculated direction
		area.global_position += hazard_data["direction"] * hazard_data["speed"] * delta

		# Clean up the hazard if it travels too far past the player to save memory
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

	# --- Generate the Noise Mesh Visually ---
	var mesh_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	
	var mat = StandardMaterial3D.new()
	var noise_tex = NoiseTexture2D.new()
	noise_tex.noise = FastNoiseLite.new()
	noise_tex.noise.seed = randi()
	noise_tex.noise.frequency = 0.05
	
	# Use the noise texture as a heightmap to distort the sphere into a "noise mesh"
	mat.heightmap_enabled = true
	mat.heightmap_scale = 1.5 
	mat.heightmap_texture = noise_tex
	mat.albedo_color = Color(randf_range(0.3, 1), randf_range(0.3, 1), randf_range(0.3, 1))

	sphere_mesh.material = mat
	mesh_instance.mesh = sphere_mesh
	area.add_child(mesh_instance)

	# --- Add Collision ---
	var collision = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 0.5
	collision.shape = shape
	area.add_child(collision)

	# --- Calculate Movement Variables ---
	# We want it to move toward where the player was when it spawned
	var target_dir = (player.global_position - area.global_position).normalized()
	var speed = randf_range(min_speed, max_speed)

	# Store it in our tracking array
	active_hazards.append({
		"node": area,
		"direction": target_dir,
		"speed": speed
	})
