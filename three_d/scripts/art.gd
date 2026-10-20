extends RefCounted
## Shared procedural helpers and normalized uploaded art instances.

static var materials: Dictionary = {}
static var rounded_boxes: Dictionary = {}
static var leaf_materials: Dictionary = {}
static var leaf_mesh: SphereMesh


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
	n.font_size = 28
	n.pixel_size = 0.001
	n.fixed_size = true
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.modulate = color
	n.outline_size = 5
	n.visibility_range_begin = 2.5
	n.no_depth_test = false
	n.visibility_range_end = 20
	n.add_to_group("landmark_labels")
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
		var leaf_key := str(tint)
		if not leaf_materials.has(leaf_key):
			var leaves := ShaderMaterial.new()
			leaves.shader = preload("res://shaders/foliage.gdshader")
			leaves.set_shader_parameter("tint", tint)
			leaf_materials[leaf_key] = leaves
		if leaf_mesh == null:
			leaf_mesh = SphereMesh.new()
			leaf_mesh.radius = 1.0
			leaf_mesh.height = 2.0
			leaf_mesh.radial_segments = 12
			leaf_mesh.rings = 6
		var crowns := MultiMeshInstance3D.new()
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = leaf_mesh
		instances.use_colors = true
		instances.instance_count = 7
		crowns.multimesh = instances
		crowns.material_override = leaf_materials[leaf_key]
		n.add_child(crowns)
		for i in range(7):
			var angle := i * 2.399
			var spread := h * (0.29 if i < 5 else 0.16)
			var at_leaf := Vector3(cos(angle) * spread, h * (0.67 + i * 0.055), sin(angle) * spread)
			if i % 3 == 0:
				var branch := cone(
					n, at_leaf * Vector3(0.5, 0.85, 0.5), 0.10, 0.055, h * 0.55, Color("715646")
				)
				branch.rotation = Vector3(sin(angle) * 0.6, angle, cos(angle) * 0.6)
				branch.add_to_group("polish_detail")
			var basis := Basis.IDENTITY.scaled(
				Vector3(1.0, 0.82 + float(i % 3) * 0.1, 0.9) * h * 0.27
			)
			instances.set_instance_transform(i, Transform3D(basis, at_leaf))
			instances.set_instance_color(i, Color.WHITE.darkened(float(i % 3) * 0.07))

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
		var pine := biome == 2 or rng.randf() < 0.32
		var path := (
			"nature/tree_" + ("pine" if pine else "oak") + ("_b" if rng.randf() < 0.5 else "")
		)
		var height := rng.randf_range(4.2, 6.4)
		var tree_model := model(parent, path, height)
		tree_model.position = at
		tree_model.rotation.y = rng.randf() * TAU
		var trunk := CylinderShape3D.new()
		trunk.radius = 0.38
		trunk.height = height * 0.65
		collider(tree_model, trunk, Vector3(0, trunk.height / 2, 0))
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


static func model(parent: Node3D, path: String, extent: float, axis: int = 1) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var source: Node3D = load("res://assets/models/" + path + ".glb").instantiate()
	root.add_child(source)
	if path == "equipment/pistol":
		source.rotation.y = PI / 2
	var bounds := AABB()
	var first := true
	for node in source.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (
			(root.global_transform.affine_inverse() * node.global_transform) * node.get_aabb()
		)
		bounds = box if first else bounds.merge(box)
		first = false
	if path == "equipment/sword":
		axis = 0
	if not first:
		var factor: float = extent / maxf(bounds.size[axis], 0.001)
		source.scale *= factor
		if path != "equipment/sword":
			source.position -= (
				Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * factor
			)
	return root
