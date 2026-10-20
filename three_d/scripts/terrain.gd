extends Node3D
const Art = preload("res://scripts/art.gd")
const PALETTES = [
	[Color("79ad7c"), Color("3a7966"), Color("476976"), Color("8fced0")],
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
var index := 0
var seed_value := 0
var scale_factor := 1.0
var palette: Array = []
var anchors: Dictionary = {}
var paths: Array = []
var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var spawn_points: Array[Vector3] = []


func configure(world_seed: int, island: int) -> void:
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
		[anchors.camp, Vector2(-11, 4) * scale_factor, anchors.cave, anchors.ridge, anchors.gate],
		[anchors.camp, Vector2(14, 9) * scale_factor, anchors.ruins, anchors.ridge]
	]


func radius(angle: float) -> float:
	var phase := float(posmod(seed_value, 100)) * 0.1
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
	var hill := 11.0 * exp(-q.distance_squared_to(Vector2(-22, -24)) / 100.0)
	hill += 7.0 * exp(-q.distance_squared_to(Vector2(26, -22)) / 95.0)
	var wave := sin(q.x * 0.09) * cos(q.y * 0.08) * 1.5 + noise.get_noise_2dv(p) * 0.55
	# Accessible ramps connect landmarks; steep mountain faces remain off the trail.
	var trail := smoothstep(1.8, 6.5, path_distance(p))
	return 1.2 + wave + hill * trail + maxf(0, -q.y - 10) * 0.10


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
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.94
	st.set_material(m)
	var rings := 32
	var slices := 112
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
		var c := Vector3(a.x * 0.72, -12 - sin(i * 1.7) * 2, a.z * 0.72)
		var d := Vector3(b.x * 0.72, -12 - sin((i + 1) * 1.7) * 2, b.z * 0.72)
		for v in [a, c, b, b, c, d, c, Vector3(0, -22, 0), d]:
			cliffs.add_vertex(v)
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
	var normal := (b - a).cross(c - a).normalized()
	var mid := (a + b + c) / 3
	var path := path_distance(Vector2(mid.x, mid.z))
	var color: Color = palette[0]
	if normal.y < 0.75:
		color = palette[2]
	elif path < 1.6:
		color = Color("d9c69b") if index % 6 != 2 else Color("a6bec4")
	color = color.lightened(rng.randf_range(-0.05, 0.04))
	# Godot front faces use clockwise winding; collider faces must point upward.
	for v in [a, c, b]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(v)


func decorate() -> void:
	for i in range(130):
		var p := Vector2(rng.randf_range(-48, 48), rng.randf_range(-48, 48)) * scale_factor
		if not walkable(p, 3) or path_distance(p) < 4:
			continue
		var reserved := false
		for anchor in anchors.values():
			if p.distance_to(anchor) < 6:
				reserved = true
		if reserved:
			continue
		var at := Vector3(p.x, height_at(p), p.y)
		if i % 4 != 0:
			Art.biome_prop(self, at, rng, index % 6, palette[1])
		else:
			var rock := Art.sphere(
				self, at + Vector3(0, 0.5, 0), rng.randf_range(0.7, 1.3), palette[2]
			)
			rock.scale.y = 0.8
			var shape := SphereShape3D.new()
			shape.radius = 0.8
			Art.collider(self, shape, at + Vector3(0, 0.4, 0))
	# Instanced grasses/flowers avoid hundreds of independently processed nodes.
	var flowers := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var flower_mesh := PrismMesh.new()
	flower_mesh.size = Vector3(0.18, 0.5, 0.18)
	flower_mesh.material = Art.material(Color("e6d991"))
	mm.mesh = flower_mesh
	mm.instance_count = 240
	for i in range(240):
		var p := Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40)) * scale_factor
		var at := (
			Vector3(p.x, height_at(p) + 0.2, p.y)
			if inside(p, 3) and path_distance(p) > 2
			else Vector3(0, -40, 0)
		)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
		mm.set_instance_color(i, Color("f7dc9d") if i % 2 == 0 else Color("c1a6d6"))
	flowers.multimesh = mm
	add_child(flowers)
