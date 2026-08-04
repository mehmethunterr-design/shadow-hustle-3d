extends Node3D

const NPC_SCENE = preload("res://npc.tscn")

@onready var player = $Player
@onready var car = $Car
@onready var bike = $Bike
@onready var city_container = $CityContainer
@onready var npc_container = $NpcContainer
@onready var mission_label: Label = $CanvasLayer/HUD/MissionPanel/MissionLabel
@onready var stats_label: Label = $CanvasLayer/HUD/StatsPanel/StatsLabel
@onready var info_label: Label = $CanvasLayer/HUD/InfoLabel
@onready var joystick = $CanvasLayer/HUD/VirtualJoystick
@onready var btn_interact: Button = $CanvasLayer/HUD/Buttons/InteractButton
@onready var btn_jump: Button = $CanvasLayer/HUD/Buttons/JumpButton
@onready var btn_light: Button = $CanvasLayer/HUD/Buttons/LightAttackButton
@onready var btn_heavy: Button = $CanvasLayer/HUD/Buttons/HeavyAttackButton
@onready var btn_style: Button = $CanvasLayer/HUD/Buttons/StyleButton

var missions := [
	"Giriş: Kaşif Arda ile konuş.",
	"Pazar bölgesini keşfet ve üç farklı NPC ile konuş.",
	"Garaj bölgesine git ve arabayı sür.",
	"Rıhtıma git ve motoru sür.",
	"Üç düşman serseriyi döv.",
	"Serbest dolaşım: şehri keşfet."
]
var mission_index: int = 0
var money: int = 750
var respect: int = 0
var current_vehicle = null
var interacted_npcs := {}
var defeated_enemies: int = 0
var ui_hold := {"jump": false}
var ui_just := {"interact": false, "attack_light": false, "attack_heavy": false, "switch_style": false}

func _ready() -> void:
	add_to_group("world_manager")
	randomize()
	_build_city()
	_spawn_npcs()
	_connect_ui()
	_update_mission()
	show_info("Açık dünya hazır. WASD veya joystick ile dolaş.")
	car.set_active(false)
	bike.set_active(false)

func _process(_delta: float) -> void:
	_update_stats()
	_check_interaction()

func _physics_process(_delta: float) -> void:
	if mission_index == 4 and defeated_enemies >= 3:
		advance_mission()

func _connect_ui() -> void:
	btn_jump.button_down.connect(func(): ui_hold["jump"] = true)
	btn_jump.button_up.connect(func(): ui_hold["jump"] = false)
	btn_interact.pressed.connect(func(): ui_just["interact"] = true)
	btn_light.pressed.connect(func(): ui_just["attack_light"] = true)
	btn_heavy.pressed.connect(func(): ui_just["attack_heavy"] = true)
	btn_style.pressed.connect(func(): ui_just["switch_style"] = true)

func _update_stats() -> void:
	var vehicle_name := "Yaya"
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
	if action_name == "jump":
		if ui_hold["jump"]:
			ui_hold["jump"] = false
			return true
		return false
	if ui_just.has(action_name) and ui_just[action_name]:
		ui_just[action_name] = false
		return true
	return false

func get_move_input() -> Vector2:
	return joystick.get_output()

func _check_interaction() -> void:
	if Input.is_action_just_pressed("interact") or consume_ui_action("interact"):
		if current_vehicle != null:
			_exit_vehicle()
			return
		var nearest_npc = _nearest_npc(3.5)
		if nearest_npc:
			nearest_npc.interact()
			return
		if player.global_position.distance_to(car.global_position) < 4.0:
			_enter_vehicle(car)
			return
		if player.global_position.distance_to(bike.global_position) < 4.0:
			_enter_vehicle(bike)
			return

func on_npc_interacted(npc) -> void:
	interacted_npcs[npc.npc_name] = true
	if mission_index == 0 and npc.npc_name == "Kaşif Arda":
		advance_mission()
	elif mission_index == 1 and interacted_npcs.size() >= 3:
		advance_mission()

func register_enemy_defeat() -> void:
	defeated_enemies += 1
	if mission_index == 4:
		show_info("Düşman etkisiz: %d / 3" % defeated_enemies)

func _enter_vehicle(vehicle) -> void:
	current_vehicle = vehicle
	player.set_control_enabled(false)
	player.visible = false
	if vehicle == car:
		car.set_active(true)
		bike.set_active(false)
		show_info("Arabaya bindin. E/F ile in.")
		if mission_index == 2:
			advance_mission()
	elif vehicle == bike:
		bike.set_active(true)
		car.set_active(false)
		show_info("Motora bindin. E/F ile in.")
		if mission_index == 3:
			advance_mission()

func _exit_vehicle() -> void:
	if current_vehicle == null:
		return
	if current_vehicle == car:
		car.set_active(false)
		player.global_position = car.global_position + car.global_transform.basis.x * 2.2
	elif current_vehicle == bike:
		bike.set_active(false)
		player.global_position = bike.global_position + bike.global_transform.basis.x * 1.8
	current_vehicle = null
	player.set_control_enabled(true)
	player.visible = true
	player.get_node("CameraPivot/SpringArm3D/Camera3D").current = true
	show_info("Araçtan indin.")

func _nearest_npc(max_distance: float):
	var best = null
	var best_distance = max_distance
	for npc in npc_container.get_children():
		if not npc is CharacterBody3D:
			continue
		var d = player.global_position.distance_to(npc.global_position)
		if d < best_distance:
			best = npc
			best_distance = d
	return best

func _spawn_npcs() -> void:
	var data = [
		{"name": "Kaşif Arda", "role": "Görev Veren", "pos": Vector3(-18, 1, 15), "text": "Önce insanlarla konuş, sonra araçları dene.", "accent": Color(0.96, 0.69, 0.20), "hostile": false},
		{"name": "Tamirci Mert", "role": "Garaj", "pos": Vector3(26, 1, 28), "text": "Burada arabalar her zaman hazır.", "accent": Color(0.29, 0.72, 0.95), "hostile": false},
		{"name": "Pazarcı Elif", "role": "Çarşı", "pos": Vector3(12, 1, -12), "text": "Çarşı bölgesinde her şey bulunur.", "accent": Color(0.86, 0.38, 0.55), "hostile": false},
		{"name": "Liman Reisi", "role": "Rıhtım", "pos": Vector3(-26, 1, -28), "text": "Motorla rıhtım çevresini rahat gezersin.", "accent": Color(0.55, 0.80, 1.0), "hostile": false},
		{"name": "Serseri 01", "role": "Düşman", "pos": Vector3(8, 1, 34), "text": "Burası bizim bölgemiz!", "accent": Color(0.85, 0.22, 0.22), "hostile": true},
		{"name": "Serseri 02", "role": "Düşman", "pos": Vector3(14, 1, 38), "text": "Yaklaşma!", "accent": Color(0.75, 0.18, 0.18), "hostile": true},
		{"name": "Serseri 03", "role": "Düşman", "pos": Vector3(18, 1, 34), "text": "Dövüşmek mi istiyorsun?", "accent": Color(0.68, 0.15, 0.15), "hostile": true},
		{"name": "Motorcu Deniz", "role": "Sürücü", "pos": Vector3(-30, 1, -18), "text": "Motor çok daha çevik, dene.", "accent": Color(0.35, 0.95, 0.60), "hostile": false},
	]
	for entry in data:
		var npc = NPC_SCENE.instantiate()
		npc.global_position = entry["pos"]
		npc.npc_name = entry["name"]
		npc.role = entry["role"]
		npc.interaction_text = entry["text"]
		npc.accent = entry["accent"]
		npc.hostile = entry["hostile"]
		npc_container.add_child(npc)

func _build_city() -> void:
	_create_road(Vector3(0, 0.05, 0), Vector3(120, 0.1, 16), Color(0.14, 0.14, 0.16))
	_create_road(Vector3(0, 0.05, 0), Vector3(16, 0.1, 120), Color(0.14, 0.14, 0.16))
	_create_road(Vector3(0, 0.052, 26), Vector3(88, 0.1, 12), Color(0.15, 0.15, 0.17))
	_create_road(Vector3(-28, 0.052, -24), Vector3(14, 0.1, 48), Color(0.15, 0.15, 0.17))
	var blocks = [
		{"p": Vector3(-34, 2, 34), "s": Vector3(10, 4, 10), "c": Color(0.38, 0.42, 0.50)},
		{"p": Vector3(-20, 3, 32), "s": Vector3(10, 6, 10), "c": Color(0.28, 0.31, 0.42)},
		{"p": Vector3(-6, 4, 34), "s": Vector3(10, 8, 10), "c": Color(0.44, 0.46, 0.60)},
		{"p": Vector3(18, 3, 18), "s": Vector3(12, 6, 12), "c": Color(0.58, 0.34, 0.40)},
		{"p": Vector3(32, 4.5, 18), "s": Vector3(10, 9, 10), "c": Color(0.36, 0.52, 0.72)},
		{"p": Vector3(36, 2.5, -12), "s": Vector3(12, 5, 12), "c": Color(0.81, 0.62, 0.34)},
		{"p": Vector3(18, 2.5, -18), "s": Vector3(12, 5, 12), "c": Color(0.47, 0.67, 0.39)},
		{"p": Vector3(-12, 3, -30), "s": Vector3(18, 6, 10), "c": Color(0.29, 0.40, 0.57)},
		{"p": Vector3(-34, 3, -34), "s": Vector3(12, 6, 12), "c": Color(0.35, 0.35, 0.42)},
		{"p": Vector3(0, 7, 44), "s": Vector3(14, 14, 10), "c": Color(0.33, 0.38, 0.48)},
		{"p": Vector3(34, 6, 42), "s": Vector3(12, 12, 12), "c": Color(0.41, 0.47, 0.55)},
	]
	for block in blocks:
		_create_building(block["p"], block["s"], block["c"])
	for pos in [
		Vector3(-44, 0, 12), Vector3(-42, 0, 24), Vector3(-38, 0, -6),
		Vector3(12, 0, -36), Vector3(26, 0, -30), Vector3(42, 0, -8),
		Vector3(44, 0, 30), Vector3(-8, 0, 46), Vector3(28, 0, 46)
	]:
		_create_tree(pos)
	_create_zone_label("Merkez", Vector3(2, 0.2, 8))
	_create_zone_label("Çarşı", Vector3(26, 0.2, -16))
	_create_zone_label("Garaj", Vector3(28, 0.2, 34))
	_create_zone_label("Liman", Vector3(-26, 0.2, -30))

func _create_zone_label(text: String, position: Vector3) -> void:
	var label = Label3D.new()
	label.text = text
	label.position = position + Vector3(0, 2.3, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1, 1, 1, 0.86)
	label.font_size = 28
	city_container.add_child(label)

func _create_road(position: Vector3, size: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	body.position = position
	city_container.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	body.add_child(mesh)

func _create_building(position: Vector3, size: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	body.position = position
	city_container.add_child(body)
	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material_override = mat
	body.add_child(mesh)
	var roof = MeshInstance3D.new()
	var roof_mesh = BoxMesh.new()
	roof_mesh.size = Vector3(size.x + 0.35, 0.25, size.z + 0.35)
	roof.mesh = roof_mesh
	roof.position.y = size.y * 0.5 + 0.15
	var roof_mat = StandardMaterial3D.new()
	roof_mat.albedo_color = color.darkened(0.16)
	roof.material_override = roof_mat
	body.add_child(roof)

func _create_tree(position: Vector3) -> void:
	var root = Node3D.new()
	root.position = position
	city_container.add_child(root)
	var trunk = MeshInstance3D.new()
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.top_radius = 0.22
	trunk_mesh.height = 2.2
	trunk.mesh = trunk_mesh
	trunk.position.y = 1.1
	var t_mat = StandardMaterial3D.new()
	t_mat.albedo_color = Color(0.38, 0.23, 0.10)
	trunk.material_override = t_mat
	root.add_child(trunk)
	var crown = MeshInstance3D.new()
	var crown_mesh = SphereMesh.new()
	crown_mesh.radius = 1.4
	crown.mesh = crown_mesh
	crown.position.y = 3.2
	var c_mat = StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.18, 0.55, 0.24)
	crown.material_override = c_mat
	root.add_child(crown)
