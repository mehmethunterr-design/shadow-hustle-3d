extends Node3D

const NPC_SCENE: PackedScene = preload("res://npc.tscn")
const WORLD_SIZE: float = 320.0
const TERRAIN_RESOLUTION: int = 97

@onready var player: CharacterBody3D = $Player
@onready var car: CharacterBody3D = $Car
@onready var bike: CharacterBody3D = $Bike
@onready var city_container: Node3D = $CityContainer
@onready var npc_container: Node3D = $NpcContainer
@onready var mission_label: Label = $CanvasLayer/HUD/MissionPanel/MissionLabel
@onready var stats_label: Label = $CanvasLayer/HUD/StatsPanel/StatsLabel
@onready var info_label: Label = $CanvasLayer/HUD/InfoLabel
@onready var joystick: Control = $CanvasLayer/HUD/VirtualJoystick
@onready var btn_interact: Button = $CanvasLayer/HUD/Buttons/InteractButton
@onready var btn_jump: Button = $CanvasLayer/HUD/Buttons/JumpButton
@onready var btn_light: Button = $CanvasLayer/HUD/Buttons/LightAttackButton
@onready var btn_heavy: Button = $CanvasLayer/HUD/Buttons/HeavyAttackButton
@onready var btn_style: Button = $CanvasLayer/HUD/Buttons/StyleButton

var missions: Array[String] = [
	"Giriş: Kaşif Arda ile konuş.",
	"Pazar bölgesini keşfet ve üç farklı NPC ile konuş.",
	"Garaj bölgesine git ve arabayı sür.",
	"Rıhtıma git ve motoru sür.",
	"Üç düşman serseriyi döv.",
	"Serbest dolaşım: araziyi keşfet."
]
var mission_index: int = 0
var money: int = 750
var respect: int = 0
var current_vehicle: Node3D = null
var interacted_npcs: Dictionary = {}
var defeated_enemies: int = 0
var ui_hold: Dictionary = {"jump": false}
var ui_just: Dictionary = {"interact": false, "attack_light": false, "attack_heavy": false, "switch_style": false}

func _ready() -> void:
	add_to_group("world_manager")
	randomize()
	_disable_broken_surfaces()
	_build_landscape()
	_build_roads_and_landmarks()
	_spawn_npcs()
	_place_gameplay_objects()
	_connect_ui()
	_update_mission()
	show_info("Yeni arazi hazır. WASD veya joystick ile dolaş.")
	car.call("set_active", false)
	bike.call("set_active", false)

func _disable_broken_surfaces() -> void:
	var old_ground: Node3D = get_node_or_null("Ground") as Node3D
	if old_ground != null:
		old_ground.visible = false
		old_ground.process_mode = Node.PROCESS_MODE_DISABLED
	var terrain_3d: Node3D = get_node_or_null("Terrain3D") as Node3D
	if terrain_3d != null:
		# Terrain3D data remains in the project for later sculpting. Until texture
		# assets are painted, its black runtime surface is hidden safely.
		terrain_3d.visible = false
		terrain_3d.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in city_container.get_children():
		child.queue_free()

func _build_landscape() -> void:
	var terrain_root := Node3D.new()
	terrain_root.name = "PlayableTerrain"
	add_child(terrain_root)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainSurface"
	mesh_instance.mesh = _create_terrain_mesh()
	mesh_instance.material_override = _create_terrain_material()
	terrain_root.add_child(mesh_instance)

	var terrain_body := StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	terrain_root.add_child(terrain_body)
	var collision_shape := CollisionShape3D.new()
	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = TERRAIN_RESOLUTION
	height_shape.map_depth = TERRAIN_RESOLUTION
	height_shape.map_data = _create_height_data()
	collision_shape.shape = height_shape
	var spacing: float = WORLD_SIZE / float(TERRAIN_RESOLUTION - 1)
	collision_shape.scale = Vector3(spacing, 1.0, spacing)
	terrain_body.add_child(collision_shape)

func _create_terrain_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var spacing: float = WORLD_SIZE / float(TERRAIN_RESOLUTION - 1)
	var half_size: float = WORLD_SIZE * 0.5

	for z_index: int in range(TERRAIN_RESOLUTION):
		for x_index: int in range(TERRAIN_RESOLUTION):
			var x: float = -half_size + float(x_index) * spacing
			var z: float = -half_size + float(z_index) * spacing
			var y: float = _ground_y(x, z)
			vertices.append(Vector3(x, y, z))
			var h_left: float = _ground_y(x - spacing, z)
			var h_right: float = _ground_y(x + spacing, z)
			var h_back: float = _ground_y(x, z - spacing)
			var h_front: float = _ground_y(x, z + spacing)
			normals.append(Vector3(h_left - h_right, spacing * 2.0, h_back - h_front).normalized())
			uvs.append(Vector2(float(x_index) / float(TERRAIN_RESOLUTION - 1), float(z_index) / float(TERRAIN_RESOLUTION - 1)))

	for z_index: int in range(TERRAIN_RESOLUTION - 1):
		for x_index: int in range(TERRAIN_RESOLUTION - 1):
			var a: int = z_index * TERRAIN_RESOLUTION + x_index
			var b: int = a + 1
			var c: int = a + TERRAIN_RESOLUTION
			var d: int = c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _create_height_data() -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var spacing: float = WORLD_SIZE / float(TERRAIN_RESOLUTION - 1)
	var half_size: float = WORLD_SIZE * 0.5
	for z_index: int in range(TERRAIN_RESOLUTION):
		for x_index: int in range(TERRAIN_RESOLUTION):
			var x: float = -half_size + float(x_index) * spacing
			var z: float = -half_size + float(z_index) * spacing
			result.append(_ground_y(x, z))
	return result

func _ground_y(x: float, z: float) -> float:
	var distance_from_center: float = Vector2(x, z).length()
	var flatten: float = clamp((distance_from_center - 58.0) / 72.0, 0.0, 1.0)
	var broad_hills: float = sin(x * 0.025) * 4.2 + cos(z * 0.021) * 3.4
	var detail: float = sin((x + z) * 0.041) * 1.4 + cos((x - z) * 0.033) * 1.0
	var mountain_rim: float = max(distance_from_center - 112.0, 0.0) * 0.12
	return (broad_hills + detail) * flatten + mountain_rim

func _create_terrain_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	float detail = sin(world_position.x * 0.31) * sin(world_position.z * 0.27);
	float broad = sin(world_position.x * 0.055 + world_position.z * 0.043);
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	vec3 grass_a = vec3(0.09, 0.27, 0.10);
	vec3 grass_b = vec3(0.18, 0.39, 0.14);
	vec3 soil = vec3(0.25, 0.17, 0.09);
	vec3 rock = vec3(0.26, 0.28, 0.29);
	vec3 ground = mix(grass_a, grass_b, 0.5 + 0.25 * detail + 0.20 * broad);
	ground = mix(ground, soil, smoothstep(0.22, 0.50, slope));
	ground = mix(ground, rock, smoothstep(0.48, 0.78, slope));
	ALBEDO = ground;
	ROUGHNESS = 0.92;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _build_roads_and_landmarks() -> void:
	_create_road(Vector3(0, 0.08, 0), Vector3(150, 0.12, 13))
	_create_road(Vector3(0, 0.09, 0), Vector3(13, 0.12, 150))
	_create_road(Vector3(38, 0.10, 32), Vector3(70, 0.12, 10))
	_create_road(Vector3(-38, 0.10, -34), Vector3(70, 0.12, 10))
	for z: int in range(-66, 67, 14):
		_create_box_visual(Vector3(0, 0.18, float(z)), Vector3(0.35, 0.035, 6.0), Color(0.95, 0.78, 0.18), false)
	for x: int in range(-66, 67, 14):
		_create_box_visual(Vector3(float(x), 0.18, 0), Vector3(6.0, 0.035, 0.35), Color(0.95, 0.78, 0.18), false)

	_create_landmark("Gölge Karakolu", Vector3(48, 0, 48), Color(0.45, 0.06, 0.07))
	_create_landmark("Kaşif Kampı", Vector3(-48, 0, 42), Color(0.12, 0.24, 0.34))
	_create_landmark("Dağ Geçidi", Vector3(-72, 0, -64), Color(0.22, 0.20, 0.18))

	var rng := RandomNumberGenerator.new()
	rng.seed = 4082026
	for index: int in range(90):
		var position := Vector3(rng.randf_range(-145.0, 145.0), 0.0, rng.randf_range(-145.0, 145.0))
		if abs(position.x) < 12.0 or abs(position.z) < 12.0 or position.length() < 58.0:
			continue
		position.y = _ground_y(position.x, position.z)
		_create_tree(position, rng.randf_range(0.75, 1.45))

func _create_road(position: Vector3, size: Vector3) -> void:
	position.y = _ground_y(position.x, position.z) + position.y
	_create_box_visual(position, size, Color(0.055, 0.060, 0.070), true)

func _create_landmark(title: String, position: Vector3, color: Color) -> void:
	position.y = _ground_y(position.x, position.z)
	_create_box_visual(position + Vector3(0, 2.5, 0), Vector3(13, 5, 10), color, true)
	_create_box_visual(position + Vector3(0, 5.35, 0), Vector3(15, 0.7, 12), color.lightened(0.12), false)
	var label := Label3D.new()
	label.text = title
	label.position = position + Vector3(0, 7.0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 30
	label.modulate = Color(1.0, 0.92, 0.75)
	city_container.add_child(label)

func _create_box_visual(position: Vector3, size: Vector3, color: Color, collision: bool) -> void:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.position = position
	city_container.add_child(root)
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	if collision:
		var collision_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
		root.add_child(collision_shape)

func _create_tree(position: Vector3, size_scale: float) -> void:
	var root := Node3D.new()
	root.position = position
	root.scale = Vector3.ONE * size_scale
	city_container.add_child(root)
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.top_radius = 0.20
	trunk_mesh.height = 3.2
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.6
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.20, 0.11, 0.055)
	trunk.material_override = trunk_material
	root.add_child(trunk)
	for level: int in range(3):
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.45 - float(level) * 0.20
		cone.height = 2.1
		crown.mesh = cone
		crown.position.y = 3.0 + float(level) * 0.9
		var crown_material := StandardMaterial3D.new()
		crown_material.albedo_color = Color(0.035, 0.20 + float(level) * 0.025, 0.075)
		crown.material_override = crown_material
		root.add_child(crown)

func _spawn_npcs() -> void:
	var data: Array[Dictionary] = [
		{"name":"Kaşif Arda", "role":"Görev Veren", "pos":Vector3(-18, 0, 15), "text":"Yeni araziyi birlikte keşfedelim.", "accent":Color(0.96,0.69,0.20), "hostile":false},
		{"name":"Tamirci Mert", "role":"Garaj", "pos":Vector3(26,0,28), "text":"Araçlar yol kenarında hazır.", "accent":Color(0.29,0.72,0.95), "hostile":false},
		{"name":"Pazarcı Elif", "role":"Kamp", "pos":Vector3(-38,0,38), "text":"Kamp çevresinde malzeme bulunur.", "accent":Color(0.86,0.38,0.55), "hostile":false},
		{"name":"Liman Reisi", "role":"Gezgin", "pos":Vector3(-30,0,-28), "text":"Dağ geçidine dikkat et.", "accent":Color(0.55,0.80,1.0), "hostile":false},
		{"name":"Serseri 01", "role":"Düşman", "pos":Vector3(42,0,38), "text":"Burası bizim bölgemiz!", "accent":Color(0.85,0.22,0.22), "hostile":true},
		{"name":"Serseri 02", "role":"Düşman", "pos":Vector3(50,0,42), "text":"Yaklaşma!", "accent":Color(0.75,0.18,0.18), "hostile":true},
		{"name":"Serseri 03", "role":"Düşman", "pos":Vector3(56,0,36), "text":"Dövüşmek mi istiyorsun?", "accent":Color(0.68,0.15,0.15), "hostile":true}
	]
	for entry: Dictionary in data:
		var npc: CharacterBody3D = NPC_SCENE.instantiate() as CharacterBody3D
		var position: Vector3 = entry["pos"] as Vector3
		position.y = _ground_y(position.x, position.z) + 0.95
		npc.position = position
		npc.set("npc_name", str(entry["name"]))
		npc.set("role", str(entry["role"]))
		npc.set("interaction_text", str(entry["text"]))
		npc.set("accent", entry["accent"])
		npc.set("hostile", bool(entry["hostile"]))
		npc_container.add_child(npc)

func _place_gameplay_objects() -> void:
	player.position = Vector3(0, _ground_y(0, 10) + 1.05, 10)
	car.position = Vector3(26, _ground_y(26, 24) + 1.0, 24)
	bike.position = Vector3(-28, _ground_y(-28, -24) + 1.0, -24)

func _connect_ui() -> void:
	btn_jump.button_down.connect(func() -> void: ui_hold["jump"] = true)
	btn_jump.button_up.connect(func() -> void: ui_hold["jump"] = false)
	btn_interact.pressed.connect(func() -> void: ui_just["interact"] = true)
	btn_light.pressed.connect(func() -> void: ui_just["attack_light"] = true)
	btn_heavy.pressed.connect(func() -> void: ui_just["attack_heavy"] = true)
	btn_style.pressed.connect(func() -> void: ui_just["switch_style"] = true)

func _process(_delta: float) -> void:
	_update_stats()
	_check_interaction()

func _physics_process(_delta: float) -> void:
	if mission_index == 4 and defeated_enemies >= 3:
		advance_mission()

func _update_stats() -> void:
	var vehicle_name: String = "Yaya"
	if current_vehicle == car:
		vehicle_name = "Araba"
	elif current_vehicle == bike:
		vehicle_name = "Motor"
	stats_label.text = "Para: %d ₺\nSaygınlık: %d\nGörev: %d / %d\nAraç: %s" % [money, respect, mission_index + 1, missions.size(), vehicle_name]

func _update_mission() -> void:
	mission_label.text = "Görev\n" + missions[min(mission_index, missions.size() - 1)]

func advance_mission() -> void:
	if mission_index < missions.size() - 1:
		mission_index += 1
		money += 250
		respect += 10
		_update_mission()
		show_info("Yeni görev açıldı! +250 ₺, +10 Saygınlık")

func show_info(text: String) -> void:
	info_label.text = text

func consume_ui_action(action_name: String) -> bool:
	if action_name == "jump" and bool(ui_hold["jump"]):
		ui_hold["jump"] = false
		return true
	if ui_just.has(action_name) and bool(ui_just[action_name]):
		ui_just[action_name] = false
		return true
	return false

func get_move_input() -> Vector2:
	return joystick.call("get_output") as Vector2

func _check_interaction() -> void:
	if not Input.is_action_just_pressed("interact") and not consume_ui_action("interact"):
		return
	if current_vehicle != null:
		_exit_vehicle()
		return
	var nearest_npc: CharacterBody3D = _nearest_npc(3.5)
	if nearest_npc != null:
		nearest_npc.call("interact")
		return
	if player.global_position.distance_to(car.global_position) < 4.0:
		_enter_vehicle(car)
	elif player.global_position.distance_to(bike.global_position) < 4.0:
		_enter_vehicle(bike)

func _nearest_npc(max_distance: float) -> CharacterBody3D:
	var best: CharacterBody3D = null
	var best_distance: float = max_distance
	for child: Node in npc_container.get_children():
		if child is CharacterBody3D:
			var npc := child as CharacterBody3D
			var distance: float = player.global_position.distance_to(npc.global_position)
			if distance < best_distance:
				best = npc
				best_distance = distance
	return best

func on_npc_interacted(npc: Node) -> void:
	var npc_name: String = str(npc.get("npc_name"))
	interacted_npcs[npc_name] = true
	if mission_index == 0 and npc_name == "Kaşif Arda":
		advance_mission()
	elif mission_index == 1 and interacted_npcs.size() >= 3:
		advance_mission()

func register_enemy_defeat() -> void:
	defeated_enemies += 1
	if mission_index == 4:
		show_info("Düşman etkisiz: %d / 3" % defeated_enemies)

func _enter_vehicle(vehicle: Node3D) -> void:
	current_vehicle = vehicle
	player.call("set_control_enabled", false)
	player.visible = false
	if vehicle == car:
		car.call("set_active", true)
		bike.call("set_active", false)
		show_info("Arabaya bindin. E/F ile in.")
		if mission_index == 2:
			advance_mission()
	else:
		bike.call("set_active", true)
		car.call("set_active", false)
		show_info("Motora bindin. E/F ile in.")
		if mission_index == 3:
			advance_mission()

func _exit_vehicle() -> void:
	if current_vehicle == null:
		return
	if current_vehicle == car:
		car.call("set_active", false)
		player.global_position = car.global_position + car.global_transform.basis.x * 2.2
	else:
		bike.call("set_active", false)
		player.global_position = bike.global_position + bike.global_transform.basis.x * 1.8
	current_vehicle = null
	player.call("set_control_enabled", true)
	player.visible = true
	var player_camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D") as Camera3D
	player_camera.current = true
	show_info("Araçtan indin.")
