extends Node3D

@onready var imported_model: Node3D = $ImportedSkeleton
@onready var fallback_body: Node3D = $FallbackNinja
@onready var attack_flash: MeshInstance3D = $AttackFlash

var animation_player: AnimationPlayer = null
var locomotion_speed: float = 0.0
var is_attacking: bool = false
var current_style: String = "Shadow"
var current_locomotion: StringName = &""

func _ready() -> void:
	imported_model.visible = true
	imported_model.position.y = -0.48
	fallback_body.visible = false
	attack_flash.visible = false
	animation_player = _find_animation_player(imported_model)
	_play_best(["idle"], true)

func _process(_delta: float) -> void:
	if is_attacking:
		return
	if locomotion_speed > 8.5:
		_set_locomotion_animation(["running_a", "run", "running"])
	elif locomotion_speed > 0.3:
		_set_locomotion_animation(["walking_a", "walk", "walking"])
	else:
		_set_locomotion_animation(["idle"])

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child: Node in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _find_animation(keywords: Array[String]) -> StringName:
	if animation_player == null:
		return &""
	var names: PackedStringArray = animation_player.get_animation_list()
	for keyword: String in keywords:
		var needle: String = keyword.to_lower()
		for item: String in names:
			if item.to_lower().contains(needle):
				return StringName(item)
	return &""

func _play_best(keywords: Array[String], looped: bool = false, speed_scale: float = 1.0) -> bool:
	if animation_player == null:
		return false
	var animation_name: StringName = _find_animation(keywords)
	if animation_name == &"":
		return false
	var animation: Animation = animation_player.get_animation(animation_name)
	if animation != null and looped:
		animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.speed_scale = speed_scale
	animation_player.play(animation_name, 0.12)
	return true

func _set_locomotion_animation(keywords: Array[String]) -> void:
	var animation_name: StringName = _find_animation(keywords)
	if animation_name == &"" or animation_name == current_locomotion:
		return
	current_locomotion = animation_name
	var animation: Animation = animation_player.get_animation(animation_name)
	if animation != null:
		animation.loop_mode = Animation.LOOP_LINEAR
	animation_player.speed_scale = 1.0
	animation_player.play(animation_name, 0.16)

func set_locomotion(speed: float, _on_floor: bool) -> void:
	locomotion_speed = speed

func set_style(style_name: String) -> void:
	current_style = style_name

func play_attack(combo_index: int, heavy: bool) -> void:
	if animation_player == null:
		return
	is_attacking = true
	current_locomotion = &""
	var candidates: Array[String]
	if heavy:
		candidates = ["1h_melee_attack_chop", "attack_chop", "melee_attack"]
	elif combo_index == 1:
		candidates = ["1h_melee_attack_slice_horizontal", "attack_slice_horizontal", "attack_slice"]
	elif combo_index == 2:
		candidates = ["1h_melee_attack_slice_diagonal", "attack_slice_diagonal", "attack_slice"]
	else:
		candidates = ["1h_melee_attack_stab", "attack_stab", "melee_attack"]
	if not _play_best(candidates, false, 1.1):
		is_attacking = false
		return
	attack_flash.visible = true
	var duration: float = 0.55
	if animation_player.current_animation_length > 0.0:
		duration = animation_player.current_animation_length / max(animation_player.speed_scale, 0.01)
	await get_tree().create_timer(min(duration, 1.2)).timeout
	attack_flash.visible = false
	is_attacking = false

func play_dash() -> void:
	if animation_player == null:
		return
	is_attacking = true
	current_locomotion = &""
	if not _play_best(["dodge_forward", "dodge"], false, 1.2):
		is_attacking = false
		return
	var duration: float = 0.45
	if animation_player.current_animation_length > 0.0:
		duration = animation_player.current_animation_length / max(animation_player.speed_scale, 0.01)
	await get_tree().create_timer(min(duration, 0.8)).timeout
	is_attacking = false
