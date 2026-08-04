extends Node

var configured: bool = false

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_try_configure_world")

func _on_node_added(_node: Node) -> void:
	call_deferred("_try_configure_world")

func _try_configure_world() -> void:
	if configured:
		return
	var scene: Node = get_tree().current_scene
	if scene == null or scene.name != "Main":
		return
	var terrain: Node = scene.get_node_or_null("Terrain3D")
	if terrain == null:
		return
	configured = true
	await get_tree().process_frame
	await get_tree().process_frame
	_remove_legacy_world(scene)
	_configure_terrain(terrain)
	_snap_world_to_terrain(scene, terrain)

func _remove_legacy_world(scene: Node) -> void:
	for node_name: String in ["Ground", "ShadowHustleWilderness"]:
		var old_node: Node = scene.get_node_or_null(node_name)
		if old_node != null:
			old_node.queue_free()
	var city: Node = scene.get_node_or_null("CityContainer")
	if city != null:
		for child: Node in city.get_children():
			child.queue_free()

func _configure_terrain(terrain: Node) -> void:
	if _has_property(terrain, &"collision_enabled"):
		terrain.set("collision_enabled", true)
	var material: Object = terrain.get("material")
	if material != null and _has_property(material, &"show_checkered"):
		material.set("show_checkered", false)

func _snap_world_to_terrain(scene: Node, terrain: Node) -> void:
	var placements: Dictionary = {
		"Player": Vector3(0.0, 0.0, 10.0),
		"Car": Vector3(26.0, 0.0, 24.0),
		"Bike": Vector3(-28.0, 0.0, -24.0)
	}
	for node_name: String in placements.keys():
		var actor: Node3D = scene.get_node_or_null(node_name) as Node3D
		if actor == null:
			continue
		var target: Vector3 = placements[node_name]
		target.y = _terrain_height(terrain, target) + _actor_clearance(node_name)
		actor.global_position = target
	var npc_container: Node = scene.get_node_or_null("NpcContainer")
	if npc_container != null:
		for child: Node in npc_container.get_children():
			if child is Node3D:
				var npc: Node3D = child as Node3D
				var p: Vector3 = npc.global_position
				p.y = _terrain_height(terrain, p) + 0.08
				npc.global_position = p

func _terrain_height(terrain: Node, world_position: Vector3) -> float:
	var data: Object = terrain.get("data")
	if data != null and data.has_method("get_height"):
		var result: Variant = data.call("get_height", world_position)
		if result is float or result is int:
			var height: float = float(result)
			if not is_nan(height) and not is_inf(height):
				return height
	return 0.0

func _actor_clearance(node_name: String) -> float:
	match node_name:
		"Player":
			return 0.08
		"Car", "Bike":
			return 0.7
		_:
			return 0.05

func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false
