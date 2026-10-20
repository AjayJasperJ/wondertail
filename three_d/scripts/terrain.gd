extends Node3D
const Art = preload("res://scripts/art.gd")
const PALETTES = [
	[Color("577d59"), Color("326455"), Color("476976"), Color("8fced0")],
	[Color("c9af78"), Color("879777"), Color("9c8277"), Color("80bdbb")],
	[Color("d0e2df"), Color("608c94"), Color("687e94"), Color("a4cedf")],
	[Color("8a839e"), Color("596e95"), Color("535770"), Color("a2b9d6")],
	[Color("716d75"), Color("986c65"), Color("4e515f"), Color("e9a576")],
	[Color("c6cca0"), Color("88ab96"), Color("88958b"), Color("d0d8c0")]
]
const NAMES = [
	"Mosswake Highlands",
	"Amber Dunes",
	"Frostbell Reach",
	"Moonveil Wilds",
	"Emberfall Crags",
	"Cloudgarden"
]
var layout_version := 0
var formation := 0
var landform := "Highlands"
var mountain_a := Vector2(-22, -24)
var mountain_b := Vector2(26, -22)
var index := 0
var seed_value := 0
var scale_factor := 1.0
var palette: Array = []
var anchors: Dictionary = {}
var paths: Array = []
var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var spawn_points: Array[Vector3] = []
var vertex_style: Dictionary = {}


func configure(world_seed: int, island: int, layout: int = 0) -> void:
	layout_version = layout
	seed_value = world_seed + island * 7919
	index = island
	rng.seed = seed_value
	scale_factor = rng.randf_range(0.92, 1.28)
	palette = PALETTES[posmod(index, PALETTES.size())]
	noise.seed = seed_value
	noise.frequency = 0.07
	anchors = {
		"camp": Vector2(0, 18),
		"cave": Vector2(-20, -12),
		"ruins": Vector2(20, -6),
		"ridge": Vector2(0, -23),
		"gate": Vector2(0, -34)
	}
	for key in anchors:
		anchors[key] *= scale_factor
	paths = [
		[
			anchors.camp,
			Vector2(-11, 4) * scale_factor,
			anchors.cave + Vector2(0, 4),
			anchors.cave + Vector2(7, 4),
			anchors.ridge,
			anchors.gate
		],
		[anchors.camp, Vector2(14, 9) * scale_factor, anchors.ruins, anchors.ridge]
	]

	if layout_version >= 2:
		formation = posmod(seed_value / 7 + index, 4)
		landform = ["Shattered Coast", "Windward Spine", "Three-Cape Basin", "Twin Summit"][formation]
		scale_factor = rng.randf_range(1.02, 1.55)
		var spin := rng.randf_range(-PI, PI)
		for key in anchors:
			var base: Vector2 = anchors[key].normalized() * (anchors[key].length() / 1.1)
			base = base.rotated(spin) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-2, 2))
			var maximum := radius(atan2(base.y, base.x)) - 9.0
			anchors[key] = base.limit_length(maximum)
		var sites := [anchors.ruins, anchors.cave, anchors.ridge]
		var offset := posmod(index + formation, 3)
		anchors.ruins = sites[offset]
		anchors.cave = sites[(offset + 1) % 3]
		anchors.ridge = sites[(offset + 2) % 3]
		mountain_a = Vector2(rng.randf_range(-27, -12), rng.randf_range(-26, 8))
		mountain_b = Vector2(rng.randf_range(14, 29), rng.randf_range(-23, 3))
		paths = [
			[
				anchors.camp,
				anchors.camp.lerp(anchors.cave, 0.5),
				anchors.cave,
				anchors.ridge,
				anchors.gate
			],
			[anchors.camp, anchors.camp.lerp(anchors.ruins, 0.55), anchors.ruins, anchors.ridge]
		]


func radius(angle: float) -> float:
	var phase := float(posmod(seed_value, 100)) * 0.1
	if layout_version >= 2:
		var r := 44.0
		match formation:
			0:
				r += 8 * sin(angle * 2 + phase) + 4 * cos(angle * 5)
			1:
				r = 44.0 / sqrt(pow(cos(angle) / 0.8, 2) + pow(sin(angle) / 1.32, 2))
			2:
				r += 9 * cos(angle * 3 + phase) + 4 * sin(angle * 5)
			3:
				r += 7 * cos(angle * 2 - phase) + 5 * sin(angle * 4)
		return r * scale_factor
	return (
		(43 + 4 * sin(angle * 3 + phase) + 3 * sin(angle * 5 - phase) + 2 * cos(angle * 7))
		* scale_factor
	)


func inside(p: Vector2, margin: float = 0.0) -> bool:
	return p.length() < radius(atan2(p.y, p.x)) - margin


func path_distance(p: Vector2) -> float:
	var best := 10000.0
	for route in paths:
		for i in range(route.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(p, route[i], route[i + 1])
			best = minf(best, p.distance_to(closest))
	return best


func height_at(p: Vector2) -> float:
	var q := p / scale_factor
	var hill := 11.0 * exp(-q.distance_squared_to(mountain_a) / 100.0)
	hill += 7.0 * exp(-q.distance_squared_to(mountain_b) / 95.0)
	var wave := sin(q.x * 0.09) * cos(q.y * 0.08) * 1.5 + noise.get_noise_2dv(p) * 0.55
	# Accessible ramps connect landmarks; steep mountain faces remain off the trail.
	var distance := path_distance(p)
	for anchor in anchors.values():
		distance = minf(distance, p.distance_to(anchor))
	var trail := smoothstep(1.8, 6.5, distance)
	var elevation := 1.2 + wave + hill * trail + maxf(0, -q.y - 10) * 0.10
	var pond_distance := p.distance_to(Vector2(-15, 14) * scale_factor)
	return elevation - 0.7 * (1.0 - smoothstep(2.8, 5.0, pond_distance))


func point(key: String) -> Vector3:
	var p: Vector2 = anchors[key]
	return Vector3(p.x, height_at(p), p.y)


func walkable(p: Vector2, margin: float = 2) -> bool:
	if not inside(p, margin):
		return false
	var h := height_at(p)
	return (
		absf(height_at(p + Vector2(0.8, 0)) - h) < 0.65
		and absf(height_at(p + Vector2(0, 0.8)) - h) < 0.65
	)


func build() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(Art.material(Color.WHITE))
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain_detail.gdshader")
	st.set_material(m)
	vertex_style.clear()
	var rings := 48
	var slices := 160
	for ring in range(rings):
		for i in range(slices):
			var a := TAU * i / slices
			var b := TAU * (i + 1) / slices
			var p0 := radial(a, float(ring) / rings)
			var p1 := radial(b, float(ring) / rings)
			var p2 := radial(a, float(ring + 1) / rings)
			var p3 := radial(b, float(ring + 1) / rings)
			triangle(st, p0, p1, p2)
			triangle(st, p1, p3, p2)
	var surface := MeshInstance3D.new()
	surface.mesh = st.commit()
	add_child(surface)
	surface.create_trimesh_collision()
	# Actual cliff walls, tapered underside, and a crystalline floating core.
	var cliffs := SurfaceTool.new()
	cliffs.begin(Mesh.PRIMITIVE_TRIANGLES)
	cliffs.set_material(Art.material(palette[2]))
	for i in range(slices):
		var a := radial(TAU * i / slices, 1)
		var b := radial(TAU * (i + 1) / slices, 1)
		var c := Vector3(a.x * 0.72, -12 - sin(TAU * i / slices * 3) * 1.5, a.z * 0.72)
		var d := Vector3(b.x * 0.72, -12 - sin(TAU * (i + 1) / slices * 3) * 1.5, b.z * 0.72)
		for v in [a, c, b, b, c, d, c, Vector3(0, -22, 0), d]:
			cliffs.add_vertex(v)
	cliffs.index()
	cliffs.generate_normals()
	var cliff_mesh := MeshInstance3D.new()
	cliff_mesh.mesh = cliffs.commit()
	add_child(cliff_mesh)
	cliff_mesh.create_trimesh_collision()
	decorate()


func radial(angle: float, fraction: float) -> Vector3:
	var p := Vector2(cos(angle), sin(angle)) * radius(angle) * fraction
	return Vector3(p.x, height_at(p), p.y)


func triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if a.distance_squared_to(b) < 0.0001:
		return
	# Godot front faces use clockwise winding; collider faces must point upward.
	for v in [a, c, b]:
		if not vertex_style.has(v):
			var p := Vector2(v.x, v.z)
			var e := 0.16
			var n := (
				Vector3(
					height_at(p - Vector2(e, 0)) - height_at(p + Vector2(e, 0)),
					2 * e,
					height_at(p - Vector2(0, e)) - height_at(p + Vector2(0, e))
				)
				. normalized()
			)
			var ground: Color = palette[2].lerp(palette[0], smoothstep(0.55, 0.9, n.y))
			var sand := Color("b3a080") if index % 6 != 2 else Color("a6bec4")
			ground = ground.lerp(sand, 1 - smoothstep(1.0, 2.2, path_distance(p)))
			ground = ground.lightened(
				noise.get_noise_2dv(p * 2.3) * 0.09 + noise.get_noise_2dv(p * 0.6) * 0.05
			)
			vertex_style[v] = [n, ground]
		st.set_color(vertex_style[v][1])
		st.set_normal(vertex_style[v][0])
		st.add_vertex(v)


func decorate() -> void:
	for i in range(130):
		var p := Vector2(rng.randf_range(-48, 48), rng.randf_range(-48, 48)) * scale_factor
		if (
			not walkable(p, 3)
			or path_distance(p) < 4
			or p.distance_to(Vector2(-15, 14) * scale_factor) < 7
		):
			continue
		var reserved := false
		for key in anchors:
			var anchor: Vector2 = anchors[key]
			if p.distance_to(anchor) < (10 if key == "camp" else 6):
				reserved = true
		if reserved:
			continue
		var at := Vector3(p.x, height_at(p), p.y)
		if i % 4 != 0:
			Art.biome_prop(self, at, rng, index % 6, palette[1])
		else:
			var rock := Art.model(
				self, "nature/rock" + ("_b" if i % 2 else ""), rng.randf_range(0.7, 1.3)
			)
			rock.position = at
			rock.rotation.y = rng.randf() * TAU
			for mesh in rock.find_children("*", "MeshInstance3D", true, false):
				var solid := StaticBody3D.new()
				mesh.add_child(solid)
				var shape := CollisionShape3D.new()
				shape.shape = mesh.mesh.create_convex_shape()
				solid.add_child(shape)

	# Instanced grasses/flowers avoid hundreds of independently processed nodes.
	var flowers := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var grass := SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in range(5):
		var angle := blade * 2.399
		var base := Vector3(cos(angle) * 0.09, 0, sin(angle) * 0.09)
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.04
		var tip := base + Vector3(sin(angle) * 0.08, 0.16 + blade * 0.025, cos(angle) * 0.06)
		for v in [base - side, tip, base + side, base + side, tip, base - side]:
			grass.set_color(Color("9cbb82") if v == tip else Color("557b50"))
			grass.add_vertex(v)
	grass.generate_normals()
	var grass_material := StandardMaterial3D.new()
	grass_material.vertex_color_use_as_albedo = true
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_material.roughness = 1.0
	grass.set_material(grass_material)
	var flower_mesh := grass.commit()

	mm.mesh = flower_mesh
	mm.instance_count = 520
	for i in range(520):
		var p := Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40)) * scale_factor
		var at := (
			Vector3(p.x, height_at(p) + 0.015, p.y)
			if (
				inside(p, 3)
				and path_distance(p) > 2
				and p.distance_to(Vector2(-15, 14) * scale_factor) > 5
			)
			else Vector3(0, -40, 0)
		)
		mm.set_instance_transform(
			i,
			Transform3D(
				Basis(Vector3.UP, i * 2.399).scaled(Vector3.ONE * (0.8 + float(i % 4) * 0.15)), at
			)
		)
		mm.set_instance_color(i, Color.WHITE)
	flowers.multimesh = mm
	add_child(flowers)


func guided_route(start: Vector3, finish: Vector3) -> PackedVector3Array:
	# Shortest route over the actual trail graph, with endpoint projection so
	# players are not sent straight across steep hills between landmarks.
	var nodes: Array[Vector2] = []
	var edges: Dictionary = {}
	for route in paths:
		for point in route:
			if point not in nodes:
				nodes.append(point)
	for route in paths:
		for i in range(route.size() - 1):
			var a := nodes.find(route[i])
			var b := nodes.find(route[i + 1])
			if not edges.has(a):
				edges[a] = []
			if not edges.has(b):
				edges[b] = []
			edges[a].append(b)
			edges[b].append(a)
	var from := Vector2(start.x, start.z)
	var to := Vector2(finish.x, finish.z)
	var distances := {}
	var previous := {}
	var visited := []
	# Connect to the nearest vertex. Dense authored midpoint nodes keep this
	# conservative; the final few metres lead directly to the target prop.
	var from_link := guide_projection(nodes, edges, from)
	var to_link := guide_projection(nodes, edges, to)
	var source: int = from_link.id
	var target: int = to_link.id
	if from_link.a == to_link.a and from_link.b == to_link.b:
		edges[source].append(target)
		edges[target].append(source)
	for i in range(nodes.size()):
		distances[i] = INF
	distances[source] = 0.0
	for count in range(nodes.size()):
		var current := -1
		for i in range(nodes.size()):
			if i not in visited and (current < 0 or distances[i] < distances[current]):
				current = i
		if current < 0 or current == target:
			break
		visited.append(current)
		for neighbor in edges.get(current, []):
			var candidate: float = distances[current] + nodes[current].distance_to(nodes[neighbor])
			if candidate < distances[neighbor]:
				distances[neighbor] = candidate
				previous[neighbor] = current
	var chain := [target]
	while chain[0] != source and previous.has(chain[0]):
		chain.push_front(previous[chain[0]])
	var result := PackedVector3Array([start])
	for i in chain:
		var point: Vector2 = nodes[i]
		result.append(Vector3(point.x, height_at(point) + 0.2, point.y))
	result.append(finish)
	return result


func guide_projection(nodes: Array[Vector2], edges: Dictionary, at: Vector2) -> Dictionary:
	var best := INF
	var point := at
	var a := 0
	var b := 0
	for route in paths:
		for i in range(route.size() - 1):
			var projection := Geometry2D.get_closest_point_to_segment(at, route[i], route[i + 1])
			if at.distance_squared_to(projection) < best:
				best = at.distance_squared_to(projection)
				point = projection
				a = nodes.find(route[i])
				b = nodes.find(route[i + 1])
	var id := nodes.size()
	nodes.append(point)
	edges[id] = [a, b]
	edges[a].append(id)
	edges[b].append(id)
	return {"id": id, "a": a, "b": b}
