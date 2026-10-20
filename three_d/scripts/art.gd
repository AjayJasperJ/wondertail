extends RefCounted
## Original procedural low-poly models. No external art or textures.

static var materials: Dictionary = {}
static var rounded_boxes: Dictionary = {}


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
	var key := str(size)
	if not rounded_boxes.has(key):
		rounded_boxes[key] = rounded_box(size)
	var b: Mesh = rounded_boxes[key]
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
	b.radial_segments = 16
	b.rings = 8
	return mesh(parent, b, at, color, glow)


static func cone(
	parent: Node3D, at: Vector3, bottom: float, top: float, height: float, color: Color
) -> MeshInstance3D:
	var b := CylinderMesh.new()
	b.bottom_radius = bottom
	b.top_radius = top
	b.height = height
	b.radial_segments = 16
	return mesh(parent, b, at, color)


static func rounded_box(size: Vector3) -> ArrayMesh:
	var half := size * 0.5
	var radius := minf(0.16, minf(size.x, minf(size.y, size.z)) * 0.18)
	var inner := half - Vector3.ONE * radius
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in range(3):
		var u := (axis + 1) % 3
		var w := (axis + 2) % 3
		for side in [-1, 1]:
			var us := [-half[u], -inner[u], inner[u], half[u]]
			var ws := [-half[w], -inner[w], inner[w], half[w]]
			for i in range(3):
				for j in range(3):
					var quad: Array[Vector3] = []
					for corner in [
						Vector2i(i, j),
						Vector2i(i + 1, j),
						Vector2i(i, j + 1),
						Vector2i(i + 1, j + 1)
					]:
						var p := Vector3.ZERO
						p[axis] = half[axis] * side
						p[u] = us[corner.x]
						p[w] = ws[corner.y]
						quad.append(p)
					var order := [0, 2, 1, 1, 2, 3] if side == 1 else [0, 1, 2, 1, 3, 2]
					for index in order:
						var p: Vector3 = quad[index]
						var nearest := p.clamp(-inner, inner)
						var normal := (p - nearest).normalized()
						st.set_normal(normal)
						st.add_vertex(nearest + normal * radius)
	return st.commit()


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


static func tree(
	parent: Node3D, at: Vector3, rng: RandomNumberGenerator, tint: Color, conifer: bool = false
) -> void:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	var h := rng.randf_range(3.0, 5.0)
	cone(n, Vector3(0, h * 0.35, 0), 0.3, 0.18, h * 0.7, Color("715646"))
	if conifer:
		cone(n, Vector3(0, h * 0.75, 0), h * 0.47, 0, h * 0.75, tint)
		cone(n, Vector3(0, h * 1.03, 0), h * 0.34, 0, h * 0.65, tint.lightened(0.12))
	else:
		for i in range(3):
			var crown := sphere(
				n,
				Vector3((i - 1) * h * 0.25, h * (0.85 if i == 1 else 0.75), sin(i * 2.4) * 0.4),
				h * 0.38,
				tint.lightened(i * 0.045)
			)
			crown.scale.y = 0.85
	var foliage := SphereShape3D.new()
	foliage.radius = h * 0.48
	var camera_obstacle := collider(n, foliage, Vector3(0, h * 0.9, 0))
	camera_obstacle.collision_layer = 8
	var s := CylinderShape3D.new()
	s.radius = 0.32
	s.height = h * 0.7
	collider(n, s, Vector3(0, h * 0.35, 0))


static func biome_prop(
	parent: Node3D, at: Vector3, rng: RandomNumberGenerator, biome: int, tint: Color
) -> void:
	if biome == 0 or biome == 2:
		tree(parent, at, rng, tint, biome == 2)
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
