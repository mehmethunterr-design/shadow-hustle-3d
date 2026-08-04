extends Node

var built := false

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_try_build_current_scene")

func _on_node_added(_node: Node) -> void:
	call_deferred("_try_build_current_scene")

func _try_build_current_scene() -> void:
	if built:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.name != "Main":
		return
	built = true
	_build_world(scene)

func _build_world(root: Node3D) -> void:
	var container := Node3D.new()
	container.name = "ShadowHustleWilderness"
	root.add_child(container)

	_create_ground_ring(container)
	_create_mountain_belt(container)
	_create_forest(container)
	_create_highway(container)
	_create_tunnel(container)
	_create_ninja_camp(container)
	_create_enemy_outpost(container)
	_create_viewpoint(container)
	_create_zone_labels(container)

func _create_ground_ring(parent: Node3D) -> void:
	for tile_x in range(-3, 4):
		for tile_z in range(-3, 4):
			if abs(tile_x) <= 1 and abs(tile_z) <= 1:
				continue
			var pos := Vector3(tile_x * 80.0, -0.65, tile_z * 80.0)
			_create_box(parent, pos, Vector3(80, 1.2, 80), Color(0.075, 0.16, 0.095), true)

func _create_mountain_belt(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 24081997
	for i in range(46):
		var angle := TAU * float(i) / 46.0 + rng.randf_range(-0.09, 0.09)
		var radius := rng.randf_range(150.0, 245.0)
		var height := rng.randf_range(15.0, 42.0)
		var width := rng.randf_range(18.0, 42.0)
		var p := Vector3(cos(angle) * radius, height * 0.45 - 0.2, sin(angle) * radius)
		_create_rock(parent, p, Vector3(width, height, width * rng.randf_range(0.75, 1.25)))

func _create_forest(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8142026
	for i in range(135):
		var p := Vector3(rng.randf_range(-205, 205), 0, rng.randf_range(-205, 205))
		if abs(p.x) < 68 and abs(p.z) < 68:
			continue
		if abs(p.x + 120) < 22 and abs(p.z - 25) < 60:
			continue
		_create_tree(parent, p, rng.randf_range(0.8, 1.55))

func _create_highway(parent: Node3D) -> void:
	_create_box(parent, Vector3(-118, 0.02, 0), Vector3(18, 0.16, 250), Color(0.055, 0.06, 0.075), true)
	_create_box(parent, Vector3(-74, 0.03, 92), Vector3(90, 0.14, 12), Color(0.065, 0.068, 0.08), true)
	for z in range(-110, 111, 18):
		_create_box(parent, Vector3(-118, 0.13, z), Vector3(0.38, 0.04, 7.0), Color(0.92, 0.78, 0.22), false)

func _create_tunnel(parent: Node3D) -> void:
	var base := Vector3(-118, 0, -108)
	_create_box(parent, base + Vector3(-8, 5, 0), Vector3(3, 10, 22), Color(0.10, 0.105, 0.12), true)
	_create_box(parent, base + Vector3(8, 5, 0), Vector3(3, 10, 22), Color(0.10, 0.105, 0.12), true)
	_create_box(parent, base + Vector3(0, 10, 0), Vector3(19, 3, 22), Color(0.09, 0.095, 0.11), true)
	for x in [-5.5, 5.5]:
		_create_emissive_orb(parent, base + Vector3(x, 7.2, 7), Color(0.95, 0.08, 0.10))

func _create_ninja_camp(parent: Node3D) -> void:
	var center := Vector3(116, 0, -126)
	_create_box(parent, center + Vector3(0, 0.2, 0), Vector3(42, 0.4, 34), Color(0.08, 0.09, 0.10), true)
	for offset in [Vector3(-13, 3, -8), Vector3(13, 3, -8), Vector3(0, 3, 9)]:
		_create_box(parent, center + offset, Vector3(10, 6, 8), Color(0.12, 0.13, 0.15), true)
		_create_box(parent, center + offset + Vector3(0, 3.4, 0), Vector3(12, 0.7, 10), Color(0.28, 0.025, 0.035), false)
	for p in [Vector3(-18, 3, 14), Vector3(18, 3, 14), Vector3(-18, 3, -14), Vector3(18, 3, -14)]:
		_create_emissive_orb(parent, center + p, Color(1.0, 0.03, 0.05))

func _create_enemy_outpost(parent: Node3D) -> void:
	var center := Vector3(132, 0, 116)
	_create_box(parent, center + Vector3(0, 0.15, 0), Vector3(46, 0.3, 40), Color(0.13, 0.09, 0.07), true)
	for x in [-17, 17]:
		for z in [-14, 14]:
			_create_box(parent, center + Vector3(x, 4, z), Vector3(4, 8, 4), Color(0.20, 0.14, 0.10), true)
	_create_box(parent, center + Vector3(0, 2.5, 0), Vector3(20, 5, 14), Color(0.18, 0.11, 0.08), true)
	_create_emissive_orb(parent, center + Vector3(0, 7, 0), Color(1.0, 0.32, 0.03))

func _create_viewpoint(parent: Node3D) -> void:
	var p := Vector3(-154, 18, 142)
	_create_rock(parent, p, Vector3(46, 36, 42))
	_create_box(parent, p + Vector3(0, 18.3, 0), Vector3(18, 0.5, 16), Color(0.12, 0.13, 0.14), true)
	_create_emissive_orb(parent, p + Vector3(0, 21, 0), Color(0.22, 0.52, 1.0))

func _create_zone_labels(parent: Node3D) -> void:
	_label(parent, "Dağ Geçidi", Vector3(-118, 12, -85), Color(0.85, 0.9, 1.0))
	_label(parent, "Gölge Tapınağı", Vector3(116, 10, -126), Color(1.0, 0.12, 0.16))
	_label(parent, "Düşman Karakolu", Vector3(132, 10, 116), Color(1.0, 0.45, 0.08))
	_label(parent, "Kuzey Gözetleme Tepesi", Vector3(-154, 42, 142), Color(0.3, 0.65, 1.0))

func _create_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collision: bool) -> void:
	var body: Node3D = StaticBody3D.new() if collision else Node3D.new()
	body.position = pos
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mesh.material_override = mat
	body.add_child(mesh)
	if collision:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)

func _create_rock(parent: Node3D, pos: Vector3, scale_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = Vector3(randf_range(-8, 8), randf_range(0, 180), randf_range(-8, 8))
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	mesh.mesh = sphere
	mesh.scale = scale_value
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.115, 0.13)
	mat.roughness = 1.0
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = scale_value
	shape.shape = collision
	body.add_child(shape)

func _create_tree(parent: Node3D, pos: Vector3, scale_value: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale_value
	parent.add_child(root)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.top_radius = 0.18
	trunk_mesh.height = 3.4
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.7
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.16, 0.095, 0.055)
	trunk.material_override = trunk_mat
	root.add_child(trunk)
	for y in [3.0, 4.0, 4.8]:
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.45 - (y - 3.0) * 0.22
		cone.height = 2.1
		crown.mesh = cone
		crown.position.y = y
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.045, 0.22, 0.09)
		mat.roughness = 1.0
		crown.material_override = mat
		root.add_child(crown)

func _create_emissive_orb(parent: Node3D, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.position = pos
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mesh.material_override = mat
	parent.add_child(mesh)
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = 2.0
	light.omni_range = 8.0
	parent.add_child(light)

func _label(parent: Node3D, text: String, pos: Vector3, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.font_size = 34
	parent.add_child(label)
