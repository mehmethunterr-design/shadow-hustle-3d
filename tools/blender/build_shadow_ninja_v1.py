import bpy
import math
import os
from mathutils import Vector

# Shadow Ninja V1 - Blender 3.6
# Konseptteki karaktere benzeyen, dusuk poligonlu, sifirdan prosedurel karakter olusturur.

OUT_BLEND = os.path.join(os.path.expanduser('~'), 'Documents', 'shadow_ninja_v1.blend')
OUT_GLB = os.path.join(os.path.expanduser('~'), 'Documents', 'shadow_ninja_v1.glb')


def clean_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)


def mat(name, color, metallic=0.0, roughness=0.5, emission=None):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = color
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = roughness
    if emission:
        p.inputs['Emission'].default_value = emission
        p.inputs['Emission Strength'].default_value = 4.0
    return m


def finish(obj, material, bevel=0.02):
    if material:
        obj.data.materials.append(material)
    if bevel > 0 and obj.type == 'MESH':
        b = obj.modifiers.new('Bevel', 'BEVEL')
        b.width = bevel
        b.segments = 2
    return obj


def cube(name, loc, scale, material, rot=(0, 0, 0), bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, material, bevel)


def sphere(name, loc, scale, material, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, material, 0.01)


def cyl(name, loc, radius, depth, material, rot=(0, 0, 0), vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    return finish(o, material, 0.015)


def cone(name, loc, radius1, radius2, depth, material, rot=(0, 0, 0), vertices=10):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    return finish(o, material, 0.012)


def join_objects(objects, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    objects[0].name = name
    return objects[0]


def add_sword(name, x, y, z, angle, black, red, steel):
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    root.location = (x, y, z)
    root.rotation_euler = (math.radians(18), math.radians(angle), math.radians(-angle * 0.8))
    blade = cube(name+'_blade', (0,0,0.48), (0.035,0.018,0.48), steel, bevel=0.01)
    guard = cube(name+'_guard', (0,0,-0.02), (0.14,0.035,0.03), red, bevel=0.015)
    handle = cyl(name+'_handle', (0,0,-0.22), 0.045, 0.38, black, vertices=12)
    for o in (blade, guard, handle):
        o.parent = root
    return root


def build():
    clean_scene()
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.render.engine = 'BLENDER_EEVEE'

    black = mat('SN_Black', (0.012,0.014,0.018,1), 0.05, 0.58)
    cloth = mat('SN_Cloth', (0.025,0.028,0.034,1), 0.0, 0.82)
    armor = mat('SN_Armor', (0.055,0.065,0.078,1), 0.6, 0.28)
    red = mat('SN_Red', (0.52,0.012,0.025,1), 0.12, 0.38)
    skin = mat('SN_Skin', (0.32,0.16,0.10,1), 0.0, 0.62)
    steel = mat('SN_Steel', (0.16,0.18,0.21,1), 0.78, 0.2)
    glow = mat('SN_Glow', (0.6,0.0,0.0,1), 0.1, 0.2, (1,0.005,0.005,1))

    parts = []
    # Ana atletik govde
    parts += [sphere('Pelvis',(0,0,0.93),(0.24,0.18,0.20),cloth)]
    parts += [sphere('Torso',(0,0,1.28),(0.34,0.20,0.42),cloth)]
    parts += [sphere('ChestArmor',(0,-0.035,1.35),(0.37,0.20,0.29),armor)]
    parts += [cyl('Neck',(0,0,1.67),0.09,0.16,skin)]
    parts += [sphere('Head',(0,-0.01,1.84),(0.18,0.16,0.22),skin)]

    # Maske ve gozler
    parts += [cube('Mask',(0,-0.155,1.79),(0.18,0.055,0.11),black,bevel=0.04)]
    parts += [cube('EyeL',(-0.065,-0.202,1.88),(0.042,0.012,0.012),glow,rot=(0,0,math.radians(-8)),bevel=0.006)]
    parts += [cube('EyeR',(0.065,-0.202,1.88),(0.042,0.012,0.012),glow,rot=(0,0,math.radians(8)),bevel=0.006)]

    # Sac tutamlari
    for i,(x,z,a,s) in enumerate([
        (-0.12,2.03,-18,0.16),(-0.06,2.08,-10,0.18),(0.0,2.10,0,0.19),(0.07,2.07,12,0.17),(0.13,2.02,20,0.15),
        (-0.15,1.98,-28,0.13),(0.16,1.98,28,0.13)]):
        parts += [cone('Hair%02d'%i,(x,0.0,z),0.075,0.0,s,black,rot=(math.radians(82),0,math.radians(a)),vertices=8)]

    # Kollar A-pose
    for side in (-1,1):
        sx = 1 if side>0 else -1
        parts += [sphere('Shoulder', (0.39*sx,0,1.48),(0.17,0.19,0.16),armor)]
        parts += [cyl('UpperArm',(0.54*sx,0,1.35),0.11,0.43,cloth,rot=(0,math.radians(67*sx),0))]
        parts += [cyl('Forearm',(0.76*sx,0,1.16),0.095,0.40,armor,rot=(0,math.radians(54*sx),0))]
        parts += [sphere('Hand',(0.91*sx,-0.01,1.04),(0.09,0.07,0.12),black)]
        parts += [cube('ShoulderPlate',(0.43*sx,-0.015,1.53),(0.20,0.21,0.075),armor,rot=(0,0,math.radians(12*sx)),bevel=0.045)]
        parts += [cube('RedArmBand',(0.68*sx,-0.01,1.25),(0.07,0.115,0.055),red,rot=(0,0,math.radians(35*sx)),bevel=0.02)]

    # Bacaklar
    for side in (-1,1):
        sx = 1 if side>0 else -1
        parts += [cyl('Thigh',(0.14*sx,0,0.63),0.14,0.60,cloth,rot=(0,0,math.radians(2*sx)))]
        parts += [sphere('Knee',(0.15*sx,-0.01,0.34),(0.13,0.13,0.12),armor)]
        parts += [cyl('Shin',(0.16*sx,0,0.12),0.11,0.43,armor)]
        parts += [cube('Boot',(0.17*sx,-0.055,-0.10),(0.12,0.22,0.10),black,bevel=0.035)]
        parts += [cube('KneePlate',(0.15*sx,-0.12,0.35),(0.12,0.055,0.11),armor,bevel=0.025)]

    # Kusak ve sarkan kumaslar
    parts += [cube('Belt',(0,-0.005,0.98),(0.31,0.20,0.075),red,bevel=0.025)]
    for i,(x,y,r) in enumerate([(-0.18,0.01,-8),(0,0.0,0),(0.18,0.01,8)]):
        parts += [cube('Sash%02d'%i,(x,y,0.66),(0.10,0.045,0.28),red,rot=(0,0,math.radians(r)),bevel=0.02)]
    parts += [cube('CoatL',(-0.24,0.035,0.66),(0.12,0.11,0.30),cloth,rot=(0,0,math.radians(-8)),bevel=0.025)]
    parts += [cube('CoatR',(0.24,0.035,0.66),(0.12,0.11,0.30),cloth,rot=(0,0,math.radians(8)),bevel=0.025)]

    # Gogus capraz kayislari
    parts += [cube('StrapL',(-0.10,-0.22,1.37),(0.035,0.025,0.38),red,rot=(0,math.radians(-2),math.radians(-28)),bevel=0.01)]
    parts += [cube('StrapR',(0.10,-0.22,1.37),(0.035,0.025,0.38),black,rot=(0,math.radians(2),math.radians(28)),bevel=0.01)]

    # Sirt kiliclari
    add_sword('SwordL',-0.23,0.16,1.35,-18,black,red,steel)
    add_sword('SwordR',0.23,0.16,1.35,18,black,red,steel)

    # Basit armature - oyun icin sonraki adimda agirliklandirilacak
    bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0))
    arm = bpy.context.object
    arm.name = 'ShadowNinja_Rig'
    eb = arm.data.edit_bones
    root = eb[0]
    root.name = 'root'
    root.head=(0,0,0); root.tail=(0,0,0.95)
    pelvis=eb.new('pelvis'); pelvis.head=(0,0,0.95); pelvis.tail=(0,0,1.15); pelvis.parent=root
    spine=eb.new('spine'); spine.head=(0,0,1.15); spine.tail=(0,0,1.55); spine.parent=pelvis
    neck=eb.new('neck'); neck.head=(0,0,1.55); neck.tail=(0,0,1.72); neck.parent=spine
    head=eb.new('head'); head.head=(0,0,1.72); head.tail=(0,0,2.02); head.parent=neck
    for side,label in [(-1,'L'),(1,'R')]:
        ua=eb.new('upper_arm.'+label); ua.head=(0.28*side,0,1.52); ua.tail=(0.62*side,0,1.28); ua.parent=spine
        fa=eb.new('forearm.'+label); fa.head=ua.tail; fa.tail=(0.87*side,0,1.08); fa.parent=ua
        hand=eb.new('hand.'+label); hand.head=fa.tail; hand.tail=(0.98*side,0,1.02); hand.parent=fa
        thigh=eb.new('thigh.'+label); thigh.head=(0.13*side,0,0.95); thigh.tail=(0.15*side,0,0.38); thigh.parent=pelvis
        shin=eb.new('shin.'+label); shin.head=thigh.tail; shin.tail=(0.16*side,0,-0.02); shin.parent=thigh
        foot=eb.new('foot.'+label); foot.head=shin.tail; foot.tail=(0.16*side,-0.22,-0.08); foot.parent=shin
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.show_in_front = True

    # Tum parcalari tek koleksiyonda tut ve armature altina parent et
    for o in parts:
        o.parent = arm

    # Zemin ve kamera
    cube('Ground',(0,0,-0.22),(2.2,2.2,0.05),mat('GroundMat',(0.015,0.018,0.022,1),0,0.9),bevel=0)
    bpy.ops.object.camera_add(location=(3.6,-6.2,2.8), rotation=(math.radians(72),0,math.radians(30)))
    cam=bpy.context.object; bpy.context.scene.camera=cam

    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format='GLB', export_apply=True, export_animations=True)
    print('SHADOW_NINJA_V1_OK')
    print(OUT_BLEND)
    print(OUT_GLB)


if __name__ == '__main__':
    build()
