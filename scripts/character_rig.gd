extends Node3D

@onready var imported_model: Node3D = $ImportedSkeleton
@onready var fallback_body: Node3D = $FallbackNinja
@onready var attack_flash: MeshInstance3D = $AttackFlash

var locomotion_speed: float = 0.0
var is_attacking: bool = false
var attack_time: float = 0.0
var current_style: String = "Shadow"

func _ready() -> void:
	# The imported skeleton asset is not a finished skinned character.
	# Keep it hidden and always show the authored Shadow Ninja fallback.
	imported_model.visible = false
	fallback_body.visible = true
	attack_flash.visible = false
	set_style("Shadow")

func _process(delta: float) -> void:
	if is_attacking:
		attack_time -= delta
		attack_flash.visible = true
		attack_flash.scale = Vector3.ONE * (1.0 + max(attack_time, 0.0) * 1.6)
		if attack_time <= 0.0:
			is_attacking = false
			attack_flash.visible = false
	else:
		var t: float = Time.get_ticks_msec() * 0.001
		var amount: float = clamp(locomotion_speed / 8.0, 0.0, 1.0)
		fallback_body.position.y = sin(t * 8.0) * 0.04 * amount
		fallback_body.rotation.z = sin(t * 6.0) * 0.025 * amount

func set_locomotion(speed: float, _on_floor: bool) -> void:
	locomotion_speed = speed

func set_style(style_name: String) -> void:
	current_style = style_name
	var body_color := Color(0.035, 0.04, 0.055)
	var accent_color := Color(0.95, 0.035, 0.055)
	if style_name == "Street":
		body_color = Color(0.05, 0.08, 0.12)
		accent_color = Color(0.1, 0.6, 1.0)
	elif style_name == "Heavy":
		body_color = Color(0.10, 0.055, 0.035)
		accent_color = Color(1.0, 0.34, 0.04)
	for node in fallback_body.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		var material := StandardMaterial3D.new()
		var accent: bool = mesh_node.name.contains("Accent") or mesh_node.name.contains("Eye") or mesh_node.name.contains("Sword")
		material.albedo_color = accent_color if accent else body_color
		material.metallic = 0.28
		material.roughness = 0.48
		if accent:
			material.emission_enabled = true
			material.emission = accent_color
			material.emission_energy_multiplier = 1.6
		mesh_node.material_override = material

func play_attack(combo_index: int, heavy: bool) -> void:
	is_attacking = true
	attack_time = 0.36 if heavy else 0.22
	fallback_body.rotation.y += deg_to_rad(16.0 if combo_index % 2 == 0 else -16.0)

func play_dash() -> void:
	fallback_body.rotation.z = deg_to_rad(-12.0)
