extends Node3D

@export var model_scale: float = 0.01
@export var model_y_offset: float = 0.0

@onready var imported_model: Node3D = $ImportedSkeleton
@onready var fallback_body: Node3D = $FallbackNinja
@onready var attack_flash: MeshInstance3D = $AttackFlash

var skeleton: Skeleton3D = null
var animation_player: AnimationPlayer = null
var available_animations: PackedStringArray = []
var locomotion_speed: float = 0.0
var is_attacking: bool = false
var attack_time: float = 0.0
var current_style: String = "Shadow"
var base_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
	imported_model.scale = Vector3.ONE * model_scale
	imported_model.position.y = model_y_offset
	base_rotation = rotation
	_find_rig_nodes(imported_model)
	fallback_body.visible = not _has_visible_mesh(imported_model)
	attack_flash.visible = false
	if animation_player != null:
		available_animations = animation_player.get_animation_list()
	_play_first_matching(["idle", "Idle", "IDLE"])

func _process(delta: float) -> void:
	if is_attacking:
		attack_time -= delta
		attack_flash.visible = true
		attack_flash.scale = Vector3.ONE * (1.0 + maxf(attack_time, 0.0) * 1.6)
		attack_flash.transparency = clampf(1.0 - attack_time * 3.0, 0.15, 0.9)
		if attack_time <= 0.0:
			is_attacking = false
			attack_flash.visible = false
	else:
		_update_locomotion_animation()

	if fallback_body.visible and not is_attacking:
		var time_value: float = float(Time.get_ticks_msec()) * 0.009
		var movement_factor: float = minf(locomotion_speed / 10.0, 1.0)
		var bob: float = sin(time_value) * movement_factor * 0.06
		fallback_body.position.y = bob

func set_locomotion(speed: float, on_floor: bool) -> void:
	locomotion_speed = speed
	if not on_floor:
		_play_first_matching(["jump", "Jump", "fall", "Fall"])

func set_style(style_name: String) -> void:
	current_style = style_name
	match style_name:
		"Shadow":
			modulate_fallback(Color(0.07, 0.08, 0.11), Color(0.85, 0.08, 0.12))
		"Street":
			modulate_fallback(Color(0.12, 0.17, 0.22), Color(0.15, 0.65, 1.0))
		"Heavy":
			modulate_fallback(Color(0.18, 0.12, 0.10), Color(1.0, 0.48, 0.08))

func play_attack(combo_index: int, heavy: bool) -> void:
	is_attacking = true
	attack_time = 0.34 if heavy else 0.22
	var candidates: Array[String] = []
	if heavy:
		candidates = ["heavy_attack", "HeavyAttack", "attack_heavy", "Attack_Heavy"]
	else:
		candidates = [
			"light_attack_%d" % combo_index,
			"attack_%d" % combo_index,
			"Attack%d" % combo_index,
			"attack",
			"Attack"
		]
	_play_first_matching(candidates, true)

func play_dash() -> void:
	_play_first_matching(["dash", "Dash", "roll", "Roll"], true)

func modulate_fallback(body_color: Color, accent_color: Color) -> void:
	for node: Node in fallback_body.find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		if mesh_node == null:
			continue
		var material: StandardMaterial3D = StandardMaterial3D.new()
		var is_accent: bool = mesh_node.name.contains("Accent") or mesh_node.name.contains("Eye")
		material.albedo_color = accent_color if is_accent else body_color
		material.metallic = 0.15
		material.roughness = 0.62
		mesh_node.material_override = material

func _update_locomotion_animation() -> void:
	if is_attacking or animation_player == null:
		return
	if locomotion_speed > 8.5:
		_play_first_matching(["run", "Run", "RUN"])
	elif locomotion_speed > 0.4:
		_play_first_matching(["walk", "Walk", "WALK"])
	else:
		_play_first_matching(["idle", "Idle", "IDLE"])

func _play_first_matching(candidates: Array[String], restart: bool = false) -> void:
	if animation_player == null:
		return
	for candidate: String in candidates:
		if animation_player.has_animation(candidate):
			if restart or animation_player.current_animation != candidate:
				animation_player.play(candidate, 0.12)
			return

func _find_rig_nodes(node: Node) -> void:
	if node is Skeleton3D and skeleton == null:
		skeleton = node as Skeleton3D
	if node is AnimationPlayer and animation_player == null:
		animation_player = node as AnimationPlayer
	for child: Node in node.get_children():
		_find_rig_nodes(child)

func _has_visible_mesh(node: Node) -> bool:
	if node is MeshInstance3D:
		return true
	for child: Node in node.get_children():
		if _has_visible_mesh(child):
			return true
	return false
