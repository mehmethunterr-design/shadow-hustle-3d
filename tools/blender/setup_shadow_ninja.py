import bpy
import math
import os
from mathutils import Vector

# Shadow Ninja otomatik kurulum betigi (Blender 3.6)
# Rogue.glb modelini iceri aktarir, sahneyi duzenler ve temel ninja aksesuarlarini ekler.

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROGUE_PATH = os.path.join(
    PROJECT_ROOT,
    "addons",
    "kaykit_character_pack_adventures",
    "Characters",
    "gltf",
    "Rogue.glb",
)


def ensure_collection(name: str):
    collection = bpy.data.collections.get(name)
    if collection is None:
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
    return collection


def move_to_collection(obj, collection):
    for old_collection in list(obj.users_collection):
        old_collection.objects.unlink(obj)
    collection.objects.link(obj)


def make_material(name: str, color, metallic=0.0, roughness=0.55, emission=None):
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Metallic"].default_value = metallic
    principled.inputs["Roughness"].default_value = roughness
    if emission is not None:
        principled.inputs["Emission"].default_value = emission
        principled.inputs["Emission Strength"].default_value = 2.5
    return material


def world_bounds(objects):
    points = []
    for obj in objects:
        if obj.type != "MESH":
            continue
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        return Vector((-0.5, -0.5, 0.0)), Vector((0.5, 0.5, 2.0))
    min_v = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    max_v = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return min_v, max_v


def add_cube(name, location, scale, material, collection, rotation=(0.0, 0.0, 0.0), bevel=0.04):
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        modifier = obj.modifiers.new("Bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.data.materials.append(material)
    move_to_collection(obj, collection)
    return obj


def add_sword(name, location, rotation, dark_mat, red_mat, collection):
    root = bpy.data.objects.new(name, None)
    collection.objects.link(root)
    root.location = location
    root.rotation_euler = rotation

    blade = add_cube(name + "_Blade", (0, 0, 0), (0.035, 0.025, 0.58), dark_mat, collection, bevel=0.015)
    blade.parent = root
    blade.location = (0, 0, 0.36)

    guard = add_cube(name + "_Guard", (0, 0, 0), (0.15, 0.04, 0.035), red_mat, collection, bevel=0.015)
    guard.parent = root
    guard.location = (0, 0, -0.23)

    handle = add_cube(name + "_Handle", (0, 0, 0), (0.045, 0.04, 0.2), dark_mat, collection, bevel=0.02)
    handle.parent = root
    handle.location = (0, 0, -0.43)
    return root


def main():
    if not os.path.exists(ROGUE_PATH):
        raise FileNotFoundError("Rogue.glb bulunamadi: " + ROGUE_PATH)

    imported_collection = ensure_collection("SHADOW_NINJA_BASE")
    accessory_collection = ensure_collection("SHADOW_NINJA_ACCESSORIES")
    rig_collection = ensure_collection("OLD_RIGS")

    # Eski Rigify iskeletlerini gizle; dosyada korunurlar.
    for object_name in ("rig", "metarig"):
        obj = bpy.data.objects.get(object_name)
        if obj is not None:
            move_to_collection(obj, rig_collection)
            obj.hide_set(True)
            obj.hide_render = True

    # Betik ikinci kez calistirilirsa onceki otomatik nesneleri temizle.
    for collection in (imported_collection, accessory_collection):
        for obj in list(collection.objects):
            bpy.data.objects.remove(obj, do_unlink=True)

    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=ROGUE_PATH)
    imported = list(set(bpy.data.objects) - before)
    for obj in imported:
        move_to_collection(obj, imported_collection)

    meshes = [obj for obj in imported if obj.type == "MESH"]
    roots = [obj for obj in imported if obj.parent is None]

    min_v, max_v = world_bounds(meshes)
    height = max(max_v.z - min_v.z, 0.01)
    target_height = 1.85
    scale_factor = target_height / height
    for root in roots:
        root.scale *= scale_factor
    bpy.context.view_layer.update()

    min_v, max_v = world_bounds(meshes)
    center = (min_v + max_v) * 0.5
    offset = Vector((-center.x, -center.y, -min_v.z))
    for root in roots:
        root.location += offset
    bpy.context.view_layer.update()

    black = make_material("SN_Black", (0.012, 0.015, 0.018, 1.0), metallic=0.05, roughness=0.62)
    dark = make_material("SN_Armor", (0.055, 0.065, 0.075, 1.0), metallic=0.55, roughness=0.32)
    red = make_material("SN_Red", (0.42, 0.008, 0.018, 1.0), metallic=0.15, roughness=0.4)
    glow = make_material("SN_EyeGlow", (0.5, 0.0, 0.0, 1.0), roughness=0.25, emission=(1.0, 0.005, 0.005, 1.0))

    # Rogue modelinin gorunumunu koyulastir.
    for mesh in meshes:
        mesh.data.materials.clear()
        mesh.data.materials.append(black)

    # Basit konsept aksesuarlar: maske, omuzluk, kusak, goz ve cift kilic.
    mask = add_cube("SN_Mask", (0.0, -0.16, 1.62), (0.18, 0.08, 0.13), black, accessory_collection, bevel=0.05)
    left_shoulder = add_cube("SN_Shoulder_L", (-0.31, 0.0, 1.42), (0.18, 0.22, 0.10), dark, accessory_collection, rotation=(0.0, 0.0, math.radians(-15)), bevel=0.05)
    right_shoulder = add_cube("SN_Shoulder_R", (0.31, 0.0, 1.42), (0.18, 0.22, 0.10), dark, accessory_collection, rotation=(0.0, 0.0, math.radians(15)), bevel=0.05)
    sash = add_cube("SN_Sash", (0.0, 0.0, 0.93), (0.28, 0.20, 0.07), red, accessory_collection, bevel=0.03)
    eye_l = add_cube("SN_Eye_L", (-0.055, -0.245, 1.72), (0.04, 0.012, 0.012), glow, accessory_collection, bevel=0.008)
    eye_r = add_cube("SN_Eye_R", (0.055, -0.245, 1.72), (0.04, 0.012, 0.012), glow, accessory_collection, bevel=0.008)

    add_sword("SN_Sword_L", (-0.23, 0.16, 1.18), (math.radians(18), math.radians(-12), math.radians(28)), dark, red, accessory_collection)
    add_sword("SN_Sword_R", (0.23, 0.16, 1.18), (math.radians(18), math.radians(12), math.radians(-28)), dark, red, accessory_collection)

    # Tum otomatik nesneleri ana armature'a parent et; ayrintili kemik baglama sonraki asamada yapilacak.
    armatures = [obj for obj in imported if obj.type == "ARMATURE"]
    parent_armature = armatures[0] if armatures else None
    if parent_armature is not None:
        for obj in accessory_collection.objects:
            if obj.parent is None:
                obj.parent = parent_armature

    # Gorunumu kolaylastir.
    for obj in bpy.context.selected_objects:
        obj.select_set(False)
    if parent_armature is not None:
        parent_armature.select_set(True)
        bpy.context.view_layer.objects.active = parent_armature

    bpy.context.scene.render.engine = "BLENDER_EEVEE"
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    print("SHADOW_NINJA_SETUP_OK")


if __name__ == "__main__":
    main()
