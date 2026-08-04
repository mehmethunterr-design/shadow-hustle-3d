extends CharacterBody3D

@export var npc_name: String = "NPC"
@export var role: String = "Vatandaş"
@export var accent: Color = Color(0.2, 0.6, 0.95)
@export var hostile: bool = false
@export var interaction_text: String = "Şehir çok büyük oldu."
@export var move_radius: float = 7.0
@export var detection_range: float = 15.0
@export var attack_range: float = 2.1
@export var lose_target_range: float = 24.0
@export var low_health_threshold: int = 28
@export var attack_damage: int = 10

@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head
@onready var name_tag: Label3D = $NameTag

var home_position: Vector3
var patrol_target: Vector3
var last_seen_position: Vector3
var health: int = 100
var speed: float = 2.8
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var world_ref: Node = null
var player_ref: Node3D = null
var attack_timer: float = 0.0
var think_timer: float = 0.0
var wait_timer: float = 0.0
var alert_timer: float = 0.0
var state: String = "PATROL"
var is_alerted: bool = false

func _ready() -> void:
	add_to_group("damageable")
	if hostile:
		add_to_group("hostile_npc")
	home_position = global_position
	patrol_target = home_position
	last_seen_position = home_position
	world_ref = get_tree().get_first_node_in_group("world_manager")
	if world_ref != null:
		player_ref = world_ref.player as Node3D
	name_tag.text = "%s\n%s" % [npc_name, role]

	var body_mat: StandardMaterial3D = StandardMaterial3D.new()
	body_mat.albedo_color = accent
	body_mesh.material_override = body_mat

	var head_mat: StandardMaterial3D = StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.96, 0.80, 0.67)
	head_mesh.material_override = head_mat
	_pick_patrol_target()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	attack_timer = max(attack_timer - delta, 0.0)
	think_timer = max(think_timer - delta, 0.0)
	wait_timer = max(wait_timer - delta, 0.0)
	alert_timer = max(alert_timer - delta, 0.0)
	if player_ref == null and world_ref != null:
		player_ref = world_ref.player as Node3D
	if not hostile:
		_update_civilian(delta)
		move_and_slide()
		return
	if think_timer <= 0.0:
		think_timer = 0.16
		_update_enemy_decision()
	match state:
		"PATROL": _patrol(delta)
		"WAIT": _wait(delta)
		"CHASE": _chase(delta)
		"ATTACK": _attack(delta)
		"SEARCH": _search(delta)
		"RETREAT": _retreat(delta)
		_: state = "PATROL"
	move_and_slide()

func _update_enemy_decision() -> void:
	if player_ref == null:
		state = "PATROL"
		return
	var distance: float = global_position.distance_to(player_ref.global_position)
	var sees_player: bool = _can_see_player()
	if health <= low_health_threshold:
		state = "RETREAT"
		return
	if sees_player:
		last_seen_position = player_ref.global_position
		is_alerted = true
		alert_timer = 5.0
		_alert_nearby_enemies()
		state = "ATTACK" if distance <= attack_range else "CHASE"
		return
	if is_alerted:
		if distance > lose_target_range and alert_timer <= 0.0:
			is_alerted = false
			state = "PATROL"
		else:
			state = "SEARCH"
		return
	if state != "WAIT":
		state = "PATROL"

func _can_see_player() -> bool:
	if player_ref == null:
		return false
	var distance: float = global_position.distance_to(player_ref.global_position)
	if distance > detection_range:
		return false
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var ray_from: Vector3 = global_position + Vector3.UP * 1.4
	var ray_to: Vector3 = player_ref.global_position + Vector3.UP * 1.1
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.exclude = [self]
	var hit: Dictionary = space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == player_ref

func _patrol(delta: float) -> void:
	if global_position.distance_to(patrol_target) < 0.9:
		state = "WAIT"
		wait_timer = randf_range(0.8, 2.4)
		_stop_horizontal(delta)
		return
	_move_toward(patrol_target, speed * 0.65, delta)

func _wait(delta: float) -> void:
	_stop_horizontal(delta)
	if wait_timer <= 0.0:
		_pick_patrol_target()
		state = "PATROL"

func _chase(delta: float) -> void:
	if player_ref == null:
		state = "SEARCH"
		return
	last_seen_position = player_ref.global_position
	_move_toward(player_ref.global_position, speed * 1.55, delta)

func _attack(delta: float) -> void:
	_stop_horizontal(delta)
	if player_ref == null:
		state = "SEARCH"
		return
	_face_target(player_ref.global_position, delta)
	if global_position.distance_to(player_ref.global_position) > attack_range + 0.45:
		state = "CHASE"
		return
	if attack_timer <= 0.0:
		attack_timer = randf_range(0.9, 1.35)
		if player_ref.has_method("take_damage"):
			player_ref.call("take_damage", attack_damage)
		if world_ref != null:
			world_ref.call("show_info", "%s vurdu! -%d HP" % [npc_name, attack_damage])

func _search(delta: float) -> void:
	if global_position.distance_to(last_seen_position) > 1.1:
		_move_toward(last_seen_position, speed, delta)
	else:
		_stop_horizontal(delta)
		if alert_timer <= 0.0:
			is_alerted = false
			_pick_patrol_target()
			state = "PATROL"

func _retreat(delta: float) -> void:
	if player_ref == null:
		state = "PATROL"
		return
	var away: Vector3 = global_position - player_ref.global_position
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.RIGHT
	var retreat_target: Vector3 = global_position + away.normalized() * 8.0
	_move_toward(retreat_target, speed * 1.75, delta)
	if global_position.distance_to(player_ref.global_position) > detection_range + 5.0:
		is_alerted = false
		state = "PATROL"

func _update_civilian(delta: float) -> void:
	var danger: Node3D = _nearest_hostile(7.0)
	if danger != null:
		var away: Vector3 = global_position - danger.global_position
		away.y = 0.0
		if away.length() < 0.01:
			away = Vector3.RIGHT
		_move_toward(global_position + away.normalized() * 6.0, speed * 1.25, delta)
		return
	if global_position.distance_to(patrol_target) < 0.8:
		_pick_patrol_target()
	_move_toward(patrol_target, speed * 0.45, delta)

func _nearest_hostile(max_distance: float) -> Node3D:
	var nearest: Node3D = null
	var nearest_distance: float = max_distance
	for enemy_node: Node in get_tree().get_nodes_in_group("hostile_npc"):
		if enemy_node == self or not enemy_node is Node3D:
			continue
		var enemy: Node3D = enemy_node as Node3D
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest

func _alert_nearby_enemies() -> void:
	for enemy_node: Node in get_tree().get_nodes_in_group("hostile_npc"):
		if enemy_node == self or not enemy_node is Node3D:
			continue
		var enemy: Node3D = enemy_node as Node3D
		if global_position.distance_to(enemy.global_position) <= 10.0 and enemy.has_method("receive_alert"):
			enemy.call("receive_alert", last_seen_position)

func receive_alert(position: Vector3) -> void:
	if not hostile:
		return
	last_seen_position = position
	is_alerted = true
	alert_timer = 5.0
	state = "SEARCH"

func _pick_patrol_target() -> void:
	patrol_target = home_position + Vector3(randf_range(-move_radius, move_radius), 0.0, randf_range(-move_radius, move_radius))

func _move_toward(target: Vector3, move_speed: float, delta: float) -> void:
	var direction: Vector3 = target - global_position
	direction.y = 0.0
	if direction.length() < 0.05:
		_stop_horizontal(delta)
		return
	direction = direction.normalized()
	velocity.x = move_toward(velocity.x, direction.x * move_speed, 10.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * move_speed, 10.0 * delta)
	_face_target(global_position + direction, delta)

func _face_target(target: Vector3, delta: float) -> void:
	var flat_target: Vector3 = Vector3(target.x, global_position.y, target.z)
	if flat_target.distance_to(global_position) < 0.01:
		return
	var desired: float = global_transform.looking_at(flat_target, Vector3.UP).basis.get_euler().y
	rotation.y = lerp_angle(rotation.y, desired, 8.0 * delta)

func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

func interact() -> void:
	if hostile:
		return
	if world_ref != null:
		world_ref.call("show_info", "%s: %s" % [npc_name, interaction_text])
		world_ref.call("on_npc_interacted", self)

func take_damage(amount: int) -> void:
	health -= amount
	if player_ref != null:
		last_seen_position = player_ref.global_position
	is_alerted = true
	alert_timer = 6.0
	state = "RETREAT" if health <= low_health_threshold else "CHASE"
	_alert_nearby_enemies()
	if world_ref != null:
		world_ref.call("show_info", "%s hasar aldı (%d HP)." % [npc_name, max(health, 0)])
	if health <= 0:
		if world_ref != null and hostile:
			world_ref.call("register_enemy_defeat")
		queue_free()
