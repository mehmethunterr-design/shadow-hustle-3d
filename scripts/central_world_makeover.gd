extends Node

var built: bool = false

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_try_build")

func _on_node_added(_node: Node) -> void:
	call_deferred("_try_build")

func _try_build() -> void:
	if built:
		return
	var scene: Node = get_tree().current_scene
	if scene == null or scene.name != "Main":
		return
	built = true
	var root := scene as Node3D
	var old_city := root.get_node_or_null("CityContainer")
	if old_city:
		old_city.visible = false
	_build_center(root)

func _build_center(root: Node3D) -> void:
	var world := Node3D.new()
	world.name = "ShadowCityRebuild"
	root.add_child(world)

	_create_box(world, Vector3(0, -0.55, 0), Vector3(180, 1.0, 180), Color(0.055, 0.12, 0.07), true)
	_create_box(world, Vector3(0, 0.03, 0), Vector3(18, 0.12, 170), Color(0.035, 0.038, 0.045), true)
	_create_box(world, Vector3(0, 0.04, 0), Vector3(170, 0.12, 18), Color(0.035, 0.038, 0.045), true)
	_create_box(world, Vector3(0, 0.08, 28), Vector3(110, 0.10, 10), Color(0.045, 0.05, 0.06), true)

	for z in range(-75, 76, 12):
		_create_box(world, Vector3(0, 0.14, z), Vector3(0.25, 0.03, 5.0), Color(0.9, 0.72, 0.18), false)
	for x in range(-75, 76, 12):
		_create_box(world, Vector3(x, 0.15, 0), Vector3(5.0, 0.03, 0.25), Color(0.9, 0.72, 0.18), false)

	var buildings := [
		[Vector3(-34, 5, 34), Vector3(20, 10, 18), Color(0.10, 0.12, 0.16)],
		[Vector3(-12, 8, 38), Vector3(18, 16, 18), Color(0.075, 0.09, 0.13)],
		[Vector3(26, 6, 36), Vector3(24, 12, 20), Color(0.13, 0.075, 0.085)],
		[Vector3(40, 9, 12), Vector3(18, 18, 20), Color(0.08, 0.11, 0.15)],
		[Vector3(38, 5, -28), Vector3(22, 10, 18), Color(0.12, 0.09, 0.075)],
		[Vector3(12, 7, -40), Vector3(22, 14, 18), Color(0.07, 0.10, 0.12)],
		[Vector3(-28, 6, -38), Vector3(26, 12, 18), Color(0.11, 0.075, 0.09)],
		[Vector3(-42, 4, -12), Vector3(18, 8, 18), Color(0.075, 0.10, 0.08)]
	]
	for data in buildings:
		_create_building(world, data[0], data[1], data[2])

	for pos in [Vector3(-12,0,16), Vector3(12,0,16), Vector3(-12,0,-16), Vector3(12,0,-16), Vector3(-54,0,6), Vector3(54,0,-6)]:
		_create_lamp(world, pos)

	for pos in [Vector3(-64,0,52), Vector3(-56,0,64), Vector3(58,0,58), Vector3(68,0,44), Vector3(-60,0,-58), Vector3(62,0,-60)]:
		_create_tree(world, pos)

	_create_gateway(world, Vector3(0, 0, -76))
	_create_hill(world, Vector3(-72, 8, -72), Vector3(38, 16, 34))
	_create_hill(world, Vector3(72, 11, -68), Vector3(42, 22, 36))
	_create_hill(world, Vector3(-74, 12, 70), Vector3(44, 24, 38))
	_create_hill(world, Vector3(74, 9, 72), Vector3(40, 18, 34))

	var label := Label3D.new()
	label.text = "SHADOW CITY"
	label.position = Vector3(0, 10, -73)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.08, 0.12)
	label.font_size = 44
	world.add_child(label)

func _create_building(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	_create_box(parent, pos, size, color, true)
	for floor_y in range(2, int(size.y), 3):
		for side_x in [-1.0, 1.0]:
			var window_pos := pos + Vector3(side_x * (size.x * 0.5 + 0.03), -size.y * 0.5 + floor_y, 0)
			_create_box(parent, window_pos, Vector3(0.08, 1.1, size.z * 0.58), Color(0.10, 0.42, 0.62), false)
	_create_box(parent, pos + Vector3(0, size.y * 0.5 + 0.5, 0), Vector3(size.x + 1.2, 0.5, size.z + 1.2), Color(0.035, 0.04, 0.05), false)

func _create_gateway(parent: Node3D, pos: Vector3) -> void:
	_create_box(parent, pos + Vector3(-8, 5, 0), Vector3(3, 10, 3), Color(0.06, 0.065, 0.08), true)
	_create_box(parent, pos + Vector3(8, 5, 0), Vector3(3, 10, 3), Color(0.06, 0.065, 0.08), true)
	_create_box(parent, pos + Vector3(0, 10, 0), Vector3(19, 2, 3), Color(0.08, 0.02, 0.03), true)
	_create_orb(parent, pos + Vector3(-8, 8, -1.8), Color(1.0, 0.02, 0.04))
	_create_orb(parent, pos + Vector3(8, 8, -1.8), Color(1.0, 0.02, 0.04))

func _create_lamp(parent: Node3D, pos: Vector3) -> void:
	_create_box(parent, pos + Vector3(0, 2.2, 0), Vector3(0.22, 4.4, 0.22), Color(0.08, 0.08, 0.09), true)
	_create_orb(parent, pos + Vector3(0, 4.5, 0), Color(1.0, 0.10, 0.12))

func _create_tree(parent: Node3D, pos: Vector3) -> void:
	_create_box(parent, pos + Vector3(0, 1.6, 0), Vector3(0.7, 3.2, 0.7), Color(0.14, 0.07, 0.035), true)
	for y in [3.1, 4.2, 5.2]:
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 2.2 - (y - 3.1) * 0.25
		cone.height = 2.5
		crown.mesh = cone
		crown.position = pos + Vector3(0, y, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.025, 0.16, 0.06)
		crown.material_override = mat
		parent.add_child(crown)

func _create_hill(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	mesh.mesh = sphere
	mesh.scale = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.055, 0.12, 0.07)
	mat.roughness = 1.0
	mesh.material_override = mat
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

func _create_orb(parent: Node3D, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.position = pos
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
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
	light.light_energy = 2.2
	light.omni_range = 9.0
	parent.add_child(light)

func _create_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collision: bool) -> void:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.position = pos
	parent.add_child(root)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	mesh.material_override = mat
	root.add_child(mesh)
	if collision:
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		root.add_child(shape)
