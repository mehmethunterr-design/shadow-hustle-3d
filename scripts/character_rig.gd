extends Node3D

@onready var imported_model = $ImportedSkeleton
@onready var fallback_body = $FallbackNinja
@onready var attack_flash = $AttackFlash
@onready var left_arm = $FallbackNinja/LeftArmPivot
@onready var right_arm = $FallbackNinja/RightArmPivot
@onready var left_leg = $FallbackNinja/LeftLegPivot
@onready var right_leg = $FallbackNinja/RightLegPivot
@onready var scarf = $FallbackNinja/Scarf

var animation_player = null
var locomotion_speed = 0.0
var attack_time = 0.0
var attack_heavy = false
var attack_combo = 1
var current_style = "Shadow"

func _ready() -> void:
	# FBX şu an yalnızca iskelet referansı olarak tutuluyor.
	# Görünür ve özgün ninja modeli her koşulda aktif kalır.
	imported_model.visible = false
	fallback_body.visible = true
	attack_flash.visible = false
	_find_animation_player(imported_model)
	set_style("Shadow")

func _process(delta: float) -> void:
	var time_value = Time.get_ticks_msec() * 0.001
	var walk_strength = clamp(locomotion_speed / 8.0, 0.0, 1.0)

	if attack_time > 0.0:
		attack_time -= delta
		_update_attack_pose()
	else:
		_update_walk_pose(time_value, walk_strength)
		attack_flash.visible = false

	scarf.rotation.z = sin(time_value * 4.0) * 0.10 + walk_strength * 0.08

func set_locomotion(speed: float, _on_floor: bool) -> void:
	locomotion_speed = speed

func set_style(style_name: String) -> void:
	current_style = style_name
	var body_color = Color(0.045, 0.05, 0.07)
	var accent_color = Color(0.90, 0.035, 0.055)

	if style_name == "Street":
		body_color = Color(0.07, 0.12, 0.18)
		accent_color = Color(0.10, 0.62, 1.0)
	elif style_name == "Heavy":
		body_color = Color(0.16, 0.08, 0.045)
		accent_color = Color(1.0, 0.42, 0.04)

	for node in fallback_body.find_children("*", "MeshInstance3D", true, false):
		var mesh_node = node as MeshInstance3D
		var material = StandardMaterial3D.new()
		var accent = mesh_node.name.contains("Accent") or mesh_node.name.contains("Eye") or mesh_node.name.contains("Blade")
		material.albedo_color = accent_color if accent else body_color
		material.metallic = 0.18
		material.roughness = 0.55
		if accent:
			material.emission_enabled = true
			material.emission = accent_color * 0.65
			material.emission_energy_multiplier = 1.8
		mesh_node.material_override = material

func play_attack(combo_index: int, heavy: bool) -> void:
	attack_combo = combo_index
	attack_heavy = heavy
	attack_time = 0.38 if heavy else 0.25
	attack_flash.visible = true

	if animation_player != null:
		_play_matching_animation(combo_index, heavy)

func play_dash() -> void:
	left_arm.rotation.x = -0.8
	right_arm.rotation.x = -0.8
	left_leg.rotation.x = 0.45
	right_leg.rotation.x = 0.45

func _update_walk_pose(time_value: float, strength: float) -> void:
	var swing = sin(time_value * 9.0) * 0.65 * strength
	left_arm.rotation.x = swing
	right_arm.rotation.x = -swing
	left_leg.rotation.x = -swing
	right_leg.rotation.x = swing
	fallback_body.position.y = abs(sin(time_value * 9.0)) * 0.045 * strength

func _update_attack_pose() -> void:
	var progress = 1.0 - clamp(attack_time / (0.38 if attack_heavy else 0.25), 0.0, 1.0)
	var arc = sin(progress * PI)
	if attack_heavy:
		right_arm.rotation.x = -1.5 + arc * 2.7
		left_arm.rotation.x = -1.1 + arc * 1.8
	else:
		if attack_combo % 2 == 0:
			left_arm.rotation.x = -1.1 + arc * 2.4
			right_arm.rotation.x = 0.35
		else:
			right_arm.rotation.x = -1.1 + arc * 2.4
			left_arm.rotation.x = 0.35
	attack_flash.scale = Vector3(0.9 + arc * 1.4, 0.28 + arc * 0.24, 1.2 + arc * 1.8)

func _find_animation_player(node: Node) -> void:
	if node is AnimationPlayer:
		animation_player = node
		return
	for child in node.get_children():
		_find_animation_player(child)

func _play_matching_animation(combo_index: int, heavy: bool) -> void:
	if animation_player == null:
		return
	var names = []
	if heavy:
		names = ["heavy_attack", "HeavyAttack", "attack_heavy"]
	else:
		names = ["light_attack_%d" % combo_index, "attack_%d" % combo_index, "attack", "Attack"]
	for anim_name in names:
		if animation_player.has_animation(anim_name):
			animation_player.play(anim_name)
			return
