extends Node3D

var animation_player: AnimationPlayer = null
var current_animation: String = ""
var last_attack_state: bool = false

func _ready() -> void:
	position.y = -0.48
	rotation_degrees.y = 180.0
	call_deferred("_setup_visual")

func _setup_visual() -> void:
	var npc: Node = get_parent()
	var costume_color: Color = Color(0.25, 0.55, 0.9)
	var hostile_value: bool = false
	var npc_name_value: String = name
	if npc != null:
		costume_color = npc.get("accent") as Color
		hostile_value = bool(npc.get("hostile"))
		npc_name_value = str(npc.get("npc_name"))
	if hostile_value:
		costume_color = Color(
			min(costume_color.r * 0.45 + 0.38, 1.0),
			costume_color.g * 0.22,
			costume_color.b * 0.22
		)
	var variant: int = abs(npc_name_value.hash()) % 4
	match variant:
		0: scale = Vector3(0.92, 0.92, 0.92)
		1: scale = Vector3(1.0, 1.06, 1.0)
		2: scale = Vector3(1.07, 0.98, 1.07)
		_: scale = Vector3(0.96, 1.10, 0.96)
	for node: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = costume_color
		material.roughness = 0.72
		material.metallic = 0.12 if hostile_value else 0.0
		mesh_node.material_override = material
	animation_player = _find_animation_player(self)
	_play_matching(["Idle", "idle"], true)

func _process(_delta: float) -> void:
	var npc: CharacterBody3D = get_parent() as CharacterBody3D
	if npc == null or animation_player == null:
		return
	var state_value: String = str(npc.get("state"))
	var attack_time: float = float(npc.get("attack_timer"))
	var attacking: bool = state_value == "ATTACK" and attack_time > 0.55
	if attacking and not last_attack_state:
		_play_matching(["1H_Melee_Attack", "Melee_Attack", "Attack"], false)
	last_attack_state = attacking
	if attacking:
		return
	var horizontal_speed: float = Vector2(npc.velocity.x, npc.velocity.z).length()
	if horizontal_speed > 3.0:
		_play_matching(["Running_A", "Running", "run"], true)
	elif horizontal_speed > 0.15:
		_play_matching(["Walking_A", "Walking", "walk"], true)
	else:
		_play_matching(["Idle", "idle"], true)

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child: Node in root.get_children():
		var found: AnimationPlayer = _find_animation_player(child)
		if found != null:
			return found
	return null

func _play_matching(candidates: Array[String], looped: bool) -> void:
	if animation_player == null:
		return
	for candidate: String in candidates:
		for animation_name: StringName in animation_player.get_animation_list():
			var clean_name: String = str(animation_name)
			if clean_name.to_lower().contains(candidate.to_lower()):
				if current_animation != clean_name:
					current_animation = clean_name
					animation_player.play(animation_name, 0.12)
				var animation: Animation = animation_player.get_animation(animation_name)
				if animation != null:
					animation.loop_mode = Animation.LOOP_LINEAR if looped else Animation.LOOP_NONE
				return
