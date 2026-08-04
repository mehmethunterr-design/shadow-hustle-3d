extends CharacterBody3D

@export var npc_name: String = "NPC"
@export var role: String = "Vatandaş"
@export var accent: Color = Color(0.2, 0.6, 0.95)
@export var hostile: bool = false
@export var interaction_text: String = "Şehir çok büyük oldu."
@export var move_radius: float = 3.0

@onready var body_mesh: MeshInstance3D = $Visuals/Body
@onready var head_mesh: MeshInstance3D = $Visuals/Head
@onready var name_tag: Label3D = $NameTag

var home_position: Vector3
var wander_target: Vector3
var health: int = 100
var speed: float = 2.8
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var world_ref
var attack_timer: float = 0.0

func _ready() -> void:
	add_to_group("damageable")
	home_position = global_position
	wander_target = home_position
	world_ref = get_tree().get_first_node_in_group("world_manager")
	name_tag.text = "%s\n%s" % [npc_name, role]

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = accent
	body_mesh.material_override = body_mat

	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.96, 0.80, 0.67)
	head_mesh.material_override = head_mat

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	attack_timer -= delta

	if hostile and world_ref and world_ref.player and global_position.distance_to(world_ref.player.global_position) < 5.0:
		var target: Vector3 = world_ref.player.global_position
		var chase: Vector3 = target - global_position
		chase.y = 0.0
		if chase.length() > 1.8:
			chase = chase.normalized()
			velocity.x = chase.x * speed * 1.3
			velocity.z = chase.z * speed * 1.3
			look_at(global_position + chase, Vector3.UP)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 12 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 12 * delta)
			if attack_timer <= 0.0:
				attack_timer = 1.2
				if world_ref:
					world_ref.show_info("%s saldırıyor!" % npc_name)
	else:
		if global_position.distance_to(wander_target) < 1.0:
			wander_target = home_position + Vector3(randf_range(-move_radius, move_radius), 0, randf_range(-move_radius, move_radius))
		var dir: Vector3 = wander_target - global_position
		dir.y = 0.0
		if dir.length() > 0.25:
			dir = dir.normalized()
			velocity.x = dir.x * speed * 0.55
			velocity.z = dir.z * speed * 0.55
			look_at(global_position + dir, Vector3.UP)
		else:
			velocity.x = move_toward(velocity.x, 0.0, 6 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 6 * delta)

	move_and_slide()

func interact() -> void:
	if world_ref:
		world_ref.show_info("%s: %s" % [npc_name, interaction_text])
		world_ref.on_npc_interacted(self)

func take_damage(amount: int) -> void:
	health -= amount
	if world_ref:
		world_ref.show_info("%s hasar aldı (%d HP)." % [npc_name, max(health, 0)])
	if health <= 0:
		if world_ref and hostile:
			world_ref.register_enemy_defeat()
		queue_free()
