extends RefCounted
## Original procedural low-poly models. No external art or textures.

static var materials: Dictionary = {}


static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + str(glow)
	if materials.has(key):
		return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	materials[key] = m
	return m


static func mesh(
	parent: Node3D, shape: Mesh, at: Vector3, color: Color, glow: float = 0.0
) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = shape
	n.position = at
	n.material_override = material(color, glow)
	parent.add_child(n)
	return n


static func box(
	parent: Node3D, at: Vector3, size: Vector3, color: Color, solid: bool = false
) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var n := mesh(parent, b, at, color)
	if solid:
		var s := BoxShape3D.new()
		s.size = size
		collider(parent, s, at)
	return n


static func sphere(
	parent: Node3D, at: Vector3, radius: float, color: Color, glow: float = 0.0
) -> MeshInstance3D:
	var b := SphereMesh.new()
	b.radius = radius
	b.height = radius * 2
	b.radial_segments = 8
	b.rings = 4
	return mesh(parent, b, at, color, glow)


static func cone(
	parent: Node3D, at: Vector3, bottom: float, top: float, height: float, color: Color
) -> MeshInstance3D:
	var b := CylinderMesh.new()
	b.bottom_radius = bottom
	b.top_radius = top
	b.height = height
	b.radial_segments = 7
	return mesh(parent, b, at, color)


static func collider(parent: Node3D, shape: Shape3D, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = shape
	body.position = at
	body.add_child(col)
	parent.add_child(body)
	return body


static func label(
	parent: Node3D, caption: String, at: Vector3, color: Color = Color("fff0bb")
) -> Label3D:
	var n := Label3D.new()
	n.text = caption
	n.position = at
	n.font_size = 40
	n.pixel_size = 0.001
	n.fixed_size = true
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.modulate = color
	n.outline_size = 8
	n.visibility_range_begin = 2.5
	n.no_depth_test = false
	n.visibility_range_end = 40
	parent.add_child(n)
	return n


static func tree(parent: Node3D, at: Vector3, rng: RandomNumberGenerator, tint: Color) -> void:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	var h := rng.randf_range(3.0, 5.0)
	cone(n, Vector3(0, h * 0.35, 0), 0.3, 0.18, h * 0.7, Color("715646"))
	cone(n, Vector3(0, h * 0.75, 0), h * 0.47, 0, h * 0.75, tint)
	cone(n, Vector3(0, h * 1.03, 0), h * 0.34, 0, h * 0.65, tint.lightened(0.12))
	var s := CylinderShape3D.new()
	s.radius = 0.32
	s.height = h * 0.7
	collider(n, s, Vector3(0, h * 0.35, 0))


static func biome_prop(
	parent: Node3D, at: Vector3, rng: RandomNumberGenerator, biome: int, tint: Color
) -> void:
	if biome == 0 or biome == 2:
		tree(parent, at, rng, tint)
		return
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	var h := rng.randf_range(2.3, 4.5)
	match biome:
		1:  # Desert: branching cacti, rather than recolored woodland.
			cone(n, Vector3(0, h / 2, 0), 0.4, 0.35, h, tint)
			for side in [-1, 1]:
				box(n, Vector3(side * 0.7, h * 0.5, 0), Vector3(1.4, 0.35, 0.4), tint)
				cone(n, Vector3(side * 1.2, h * 0.65, 0), 0.23, 0.23, h * 0.4, tint)
		3:  # Moonveil: giant luminous mushroom groves.
			cone(n, Vector3(0, h / 2, 0), 0.3, 0.2, h, Color("b1bbb8"))
			var cap := sphere(n, Vector3(0, h, 0), h * 0.6, tint.lightened(0.18), 0.15)
			cap.scale.y = 0.38
		4:  # Emberfall: jagged basalt crystal spires.
			cone(n, Vector3(0, h / 2, 0), 0.7, 0.12, h, Color("585365"))
			cone(n, Vector3(0.8, h * 0.3, 0), 0.35, 0, h * 0.6, Color("ad816c"))
		5:  # Cloudgarden: golden columns supporting leafy crowns.
			cone(n, Vector3(0, h / 2, 0), 0.4, 0.3, h, Color("cbb88e"))
			for side in [-1, 1]:
				sphere(n, Vector3(side * 0.7, h, 0), 1.0, tint)
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = h
	collider(n, shape, Vector3(0, h / 2, 0))


static func explorer(parent: Node3D, archetype: int) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var colors := [Color("e6ad66"), Color("8cbadd"), Color("8cad75")]
	var widths := [0.85, 0.7, 1.08]
	var heights := [1.0, 1.1, 0.94]
	n.scale = Vector3(widths[archetype], heights[archetype], widths[archetype])
	box(n, Vector3(0, 1.0, 0), Vector3(0.64, 0.7, 0.4), colors[archetype])
	sphere(n, Vector3(0, 1.7, 0), 0.32, Color("efc5a5"))
	cone(n, Vector3(0, 1.91, 0), 0.42, 0.26, 0.22, Color("31545e"))
	box(n, Vector3(0, 1.42, -0.23), Vector3(0.74, 0.14, 0.15), Color("f1dc98"))
	box(n, Vector3(0, 1.12, 0.32), Vector3(0.5, 0.62, 0.3), Color("614e44"))
	for x in [-0.13, 0.13]:
		sphere(n, Vector3(x, 1.73, -0.28), 0.035, Color("213b43"))
	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "Leg" + str(side)
		leg.position = Vector3(side * 0.21, 0.7, 0)
		n.add_child(leg)
		box(leg, Vector3(0, -0.28, 0), Vector3(0.24, 0.55, 0.28), Color("354f5a"))
		box(leg, Vector3(0, -0.56, -0.07), Vector3(0.27, 0.18, 0.42), Color("453e39"))
		var arm := Node3D.new()
		arm.name = "Arm" + str(side)
		arm.position = Vector3(side * 0.43, 1.28, 0)
		n.add_child(arm)
		box(arm, Vector3(0, -0.2, 0), Vector3(0.2, 0.5, 0.23), colors[archetype])
		if side == 1:
			box(arm, Vector3(0, -0.46, -0.25), Vector3(0.12, 0.12, 0.9), Color("d8e3db"))
	return n
