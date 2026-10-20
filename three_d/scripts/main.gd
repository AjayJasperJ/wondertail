extends Node3D
const Expedition = preload("res://scripts/expedition.gd")
var use_expeditions := true
var expedition
var pickup_effects: Array[Dictionary] = []
const Art = preload("res://scripts/art.gd")
const Terrain = preload("res://scripts/terrain.gd")
const Player = preload("res://scripts/player.gd")
const Creature = preload("res://scripts/creature.gd")
const Store = preload("res://scripts/save_store.gd")
const Hud = preload("res://scripts/hud.gd")
const Sound = preload("res://scripts/sound.gd")
const Arrow = preload("res://scripts/arrow.gd")
var store := Store.new()
var terrain
var player
var hud
var sound
var world := Node3D.new()
var light := DirectionalLight3D.new()
var environment := WorldEnvironment.new()
var playing := false
var in_cave := false
var guardian_defeated := false
var objects: Array[Dictionary] = []
var enemies: Array = []
var effects: Array[Dictionary] = []
var companion: Node3D
var clock := 0.0
var proximity_timer := 0.0
var nearest_id := ""
var cave_steps: Array[int] = []
var cave_sequence: Array = [0, 2, 1]
var cave_lamps: Array[Node3D] = []
var cloud_node: Node3D
var beacon: Node3D
var portal: MeshInstance3D
var nav_marker: Node3D
var mouse_drag := false
var mouse_stick := false
var lava_position := Vector3.ZERO
var preview := false
var pickup_clock := 0.0


func _ready() -> void:
	bind_inputs()
	if not store.load_save() and OS.has_feature("mobile"):
		store.data.quality = 0
	setup_environment()
	sound = Sound.new()
	add_child(sound)
	sound.set_volume(float(store.data.volume))
	add_child(world)
	build_world()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Hud.new()
	canvas.add_child(hud)
	hud.setup(self)
	sync_ground()
	apply_quality()
	get_tree().auto_accept_quit = false
	if "--preview" in OS.get_cmdline_user_args():
		preview = true
		start_game()


func bind_inputs() -> void:
	var keys := {
		"left": [KEY_A, KEY_LEFT],
		"right": [KEY_D, KEY_RIGHT],
		"forward": [KEY_W, KEY_UP],
		"back": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE],
		"attack": [KEY_F],
		"interact": [KEY_E],
		"dash": [KEY_Q],
		"sprint": [KEY_SHIFT],
		"bag": [KEY_B],
		"weapon": [KEY_TAB],
		"pause": [KEY_ESCAPE],
		"camera_mode": [KEY_C],
		"crouch": [KEY_X],
		"aim": [KEY_V],
		"shoulder": [KEY_R]
	}
	for action_name in keys:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for key in keys[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action_name, event)


func setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("527d99")
	sky_material.sky_horizon_color = Color("d9e4e2")
	sky_material.ground_bottom_color = Color("4b7b92")
	sky_material.ground_horizon_color = Color("c5d8d3")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8eafca")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 0.85
	env.fog_enabled = true
	env.fog_light_color = Color("adcaca")
	env.fog_density = 0.0028
	environment.environment = env
	add_child(environment)
	light.rotation_degrees = Vector3(-48, -35, 0)
	light.light_color = Color("ffe4b0")
	light.light_energy = 1.0
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 80
	add_child(light)


func build_world() -> void:
	objects.clear()
	enemies.clear()
	effects.clear()
	cave_lamps.clear()
	cave_steps.clear()
	in_cave = false
	guardian_defeated = false
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	terrain = Terrain.new()
	terrain.configure(
		int(store.data.seed),
		int(store.data.island),
		int(store.memory().get("layout", 0)) if use_expeditions else 0
	)
	world.add_child(terrain)
	terrain.build()
	cave_sequence = [0, 2, 1] if int(store.data.island) % 2 == 0 else [2, 1, 0]
	if use_expeditions:
		cave_sequence = [[0, 2, 1], [1, 0, 2], [2, 1, 0], [1, 2, 0]][int(store.data.island) % 4]
	build_landmarks()
	nav_marker = Node3D.new()
	world.add_child(nav_marker)
	Art.cone(nav_marker, Vector3.ZERO, 0, 0.65, 1.3, Color("f1ce86"))
	Art.sphere(nav_marker, Vector3(0, 0.9, 0), 0.18, Color("fff2bf"), 0.7)
	build_collectibles()
	build_cave()
	build_sky()
	spawn_player()
	for i in range(4):
		var route: Array = terrain.paths[i % 2]
		var p: Vector2 = route[1] + Vector2(4 if i < 2 else -4, -i * 2)
		var enemy := Creature.new()
		world.add_child(enemy)
		enemy.setup(self, Vector3(p.x, terrain.height_at(p) + 0.3, p.y))
		enemies.append(enemy)
	if not 2 in store.memory().seeds:
		var guardian := Creature.new()
		world.add_child(guardian)
		guardian.setup(self, terrain.point("ridge") + Vector3(3, 0.2, 1), true)
		enemies.append(guardian)
	else:
		guardian_defeated = true
	if use_expeditions:
		expedition = Expedition.new()
		expedition.setup(self)
	apply_quality()


func spawn_player() -> void:
	player = Player.new()
	world.add_child(player)
	player.setup(self, int(store.data.hero))
	player.position = terrain.point("camp") + Vector3(0, 0.5, 3)
	if terrain.layout_version >= 2:
		var forward: Vector2 = (terrain.anchors.ruins - terrain.anchors.camp).normalized()
		player.position = terrain.point("camp") + Vector3(forward.x * 8.5, 0.5, forward.y * 8.5)
	player.position.y = terrain.height_at(Vector2(player.position.x, player.position.z)) + 0.5
	player.arm.spring_length = 16 if not playing else 9.5


func rebuild_hero() -> void:
	if is_instance_valid(player):
		world.remove_child(player)
		player.queue_free()
	spawn_player()


func landmark(key: String) -> Node3D:
	var n := Node3D.new()
	n.position = terrain.point(key)
	world.add_child(n)
	return n


func build_landmarks() -> void:
	var stone := Color("737e72")
	var gold := Color("bba77d")
	var camp := landmark("camp")
	if terrain.layout_version >= 2:
		var forward: Vector2 = (terrain.anchors.ruins - terrain.anchors.camp).normalized()
		camp.rotation.y = atan2(-forward.y, forward.x)
	Art.box(camp, Vector3(-3, 1.0, 0), Vector3(3.8, 2.0, 3.6), Color("8b8270"), true)
	var gable_shape := PrismMesh.new()
	gable_shape.size = Vector3(3.8, 1.3, 3.6)
	var gable := Art.mesh(camp, gable_shape, Vector3(-3, 2.65, 0), Color("8b8270"))
	gable.create_convex_collision()
	for side in [-1, 1]:
		var roof := Art.box(
			camp, Vector3(-3 + side * 1.05, 2.7, 0), Vector3(2.55, 0.22, 4.25), Color("365e62")
		)
		roof.rotation.z = -side * 0.48
		roof.create_convex_collision()
		Art.box(camp, Vector3(-3 + side * 1.7, 1, 1.85), Vector3(0.15, 2.1, 0.16), Color("554b3c"))
		Art.box(
			camp, Vector3(-3 + side * 1.1, 1.25, 1.82), Vector3(0.65, 0.75, 0.09), Color("4c4a3d")
		)
		Art.box(
			camp, Vector3(-3 + side * 1.1, 1.25, 1.88), Vector3(0.48, 0.58, 0.04), Color("d3b777")
		)
		Art.box(
			camp, Vector3(-3 + side * 1.1, 1.25, 1.92), Vector3(0.045, 0.61, 0.04), Color("554b3c")
		)
		Art.box(
			camp, Vector3(-3 + side * 1.1, 1.25, 1.92), Vector3(0.52, 0.045, 0.04), Color("554b3c")
		)
	Art.box(camp, Vector3(-3, 0.85, 1.84), Vector3(0.9, 1.7, 0.12), Color("514b3e"))
	Art.sphere(camp, Vector3(-2.7, 0.85, 1.94), 0.045, Color("d6b472"))
	Art.box(camp, Vector3(-3, 0.12, 2.05), Vector3(1.4, 0.24, 0.55), stone)
	Art.box(camp, Vector3(-4.1, 3.1, -0.65), Vector3(0.65, 1.0, 0.65), Color("6e736c"))
	# Small hearth rather than an oversized glowing ball.
	for i in range(7):
		var at := Vector3(cos(i * TAU / 7) * 0.55, 0.12, sin(i * TAU / 7) * 0.55)
		var rock := Art.sphere(camp, at, 0.19, Color("747c70"))
		rock.scale.y = 0.65
	for side in [-1, 1]:
		var log := Art.box(
			camp, Vector3(0, 0.12, side * 0.12), Vector3(0.7, 0.15, 0.15), Color("68503c")
		)
		log.rotation.y = side * 0.55
	var flame := Art.sphere(camp, Vector3(0, 0.3, 0), 0.15, Color("e9ae65"), 0.25)
	flame.scale = Vector3(0.7, 1.5, 0.7)
	Art.label(camp, "WAYFARER CAMP", Vector3(-2, 4.8, 0))

	add_object("camp", camp, "camp", camp.position + Vector3(0, 0.5, 0), 3.5)
	var cave := landmark("cave")
	for side in [-1, 1]:
		var arch_wall := Art.box(
			cave, Vector3(side * 2.6, 2.4, 0), Vector3(1.5, 4.8, 3.2), stone, true
		)
		arch_wall.visible = false
	var arch_top := Art.box(cave, Vector3(0, 4.8, 0), Vector3(6.7, 1.5, 3.3), stone, true)
	arch_top.visible = false
	Art.box(cave, Vector3(0, 2, -1.3), Vector3(4, 4, 0.3), Color("203a48"), true)
	for side in [-1, 1]:
		Art.sphere(cave, Vector3(side * 1.8, 2.6, 1.7), 0.3, Color("a9dce1"), 0.9)
	Art.label(cave, "THE ECHO CAVERN", Vector3(0, 6.7, 0))
	add_object("cave", cave, "enter_cave", cave.position + Vector3(0, 0.8, 2.2), 4.0)
	for side in [-1, 1]:
		for level in range(4):
			var rock := Art.sphere(
				cave,
				Vector3(side * (2.6 + sin(level) * 0.25), 0.6 + level * 1.05, 0.65),
				1.05,
				Color("667b72").lightened(level * 0.025)
			)
			rock.scale = Vector3(0.85, 0.85, 1.4)
			rock.create_convex_collision()
	for i in range(5):
		var rock := Art.sphere(
			cave,
			Vector3((i - 2) * 1.1, 4.65 + sin(float(i) / 4 * PI) * 0.35, 0.65),
			0.95,
			Color("7d8978")
		)
		rock.scale = Vector3(0.85, 0.7, 1.55)
		rock.create_convex_collision()
	var ruins := landmark("ruins")
	for side in [-1, 1]:
		Art.cone(ruins, Vector3(side * 3.8, 2, 0), 0.6, 0.45, 4, stone)
		var s := CylinderShape3D.new()
		s.height = 4
		s.radius = 0.6
		Art.collider(ruins, s, Vector3(side * 3.8, 2, 0))
		Art.box(ruins, Vector3(side * 3.8, 4.2, 0), Vector3(1.6, 0.45, 1.6), gold)
	Art.label(
		ruins, "THE FALLEN OBSERVATORY" if use_expeditions else "THE LOST CLOUD", Vector3(0, 5.8, 0)
	)
	cloud_node = Node3D.new()
	ruins.add_child(cloud_node)
	cloud_node.position = Vector3(0, 2, 0)
	for i in range(3):
		Art.sphere(cloud_node, Vector3((i - 1) * 0.65, 0, 0), 0.7, Color("e5ece5"))
	for side in [-1, 1]:
		Art.sphere(cloud_node, Vector3(side * 0.22, 0.08, -0.58), 0.065, Color("315365"))
	if not store.memory().cloud and not use_expeditions:
		for side in [-1, 1]:
			Art.box(ruins, Vector3(side * 1.7, 1.3, 0), Vector3(0.16, 2.6, 2.8), Color("9cc8cf"))
	cloud_node.visible = not use_expeditions
	add_object("cloud", cloud_node, "cloud", ruins.position + Vector3(0, 1, 1), 3.8)
	companion = Node3D.new()
	companion.visible = false
	world.add_child(companion)
	Art.sphere(companion, Vector3.ZERO, 0.55, Color("e3efde"))
	Art.sphere(companion, Vector3(0.5, 0, 0), 0.38, Color("e3efde"))
	Art.sphere(companion, Vector3(-0.5, 0, 0), 0.38, Color("e3efde"))
	for side in [-1, 1]:
		Art.sphere(companion, Vector3(side * 0.18, 0, -0.5), 0.05, Color("315365"))
	beacon = landmark("gate")
	Art.cone(beacon, Vector3(0, 0.25, 0), 4, 4, 0.5, stone)
	for side in [-1, 1]:
		Art.box(beacon, Vector3(side * 2.7, 3.2, 0), Vector3(0.9, 6.4, 1.1), gold, true)
	Art.box(beacon, Vector3(0, 6.3, 0), Vector3(6.3, 1, 1.2), gold, true)
	portal = Art.box(beacon, Vector3(0, 3.1, 0), Vector3(4.5, 5.4, 0.08), Color("9ad9cb"))
	var portal_material := StandardMaterial3D.new()
	portal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	portal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal_material.albedo_color = Color(0.52, 0.86, 0.76, 0.45)
	portal.material_override = portal_material
	portal.visible = store.memory().restored
	Art.label(beacon, "THE SKY BEACON", Vector3(0, 8, 0))
	add_object("beacon", beacon, "beacon", beacon.position + Vector3(0, 1, 2), 4)
	# A suspended timber bridge on the ridge approach provides genuine elevation.
	var bridge_center: Vector3 = terrain.point("ridge") + Vector3(0, 0.15, 5)
	for i in range(10):
		var at := bridge_center + Vector3(0, 0, i * 0.55 - 2.5)
		Art.box(world, at, Vector3(3.1, 0.25, 0.5), Color("9e805c"), true)
		if i % 3 == 0:
			for side in [-1, 1]:
				Art.box(
					world,
					at + Vector3(side * 1.55, 0.6, 0),
					Vector3(0.12, 1.2, 0.15),
					Color("715846"),
					true
				)
	for side in [-1, 1]:
		Art.box(
			world,
			bridge_center + Vector3(side * 1.55, 1.05, 0),
			Vector3(0.08, 0.10, 5.5),
			Color("bea47c")
		)
	# Water and volcanic hazards are bounded away from every required trail.
	var pool2: Vector2 = Vector2(-15, 14) * terrain.scale_factor
	lava_position = Vector3(pool2.x, terrain.height_at(pool2) + 0.45, pool2.y)
	var pool := Art.cone(
		world,
		lava_position,
		4.5,
		4.5,
		0.12,
		Color("e99863") if int(store.data.island) % 6 == 4 else Color("70b3bd")
	)
	if int(store.data.island) % 6 != 4:
		var water := ShaderMaterial.new()
		water.shader = preload("res://shaders/water.gdshader")
		pool.material_override = water
	Art.label(
		world,
		"HOT SPRING" if int(store.data.island) % 6 == 4 else "MIRROR POOL",
		lava_position + Vector3(0, 2.3, 0),
		Color("d1e3d0")
	)
	for i in range(12):
		var rim := pool2 + Vector2(cos(i * TAU / 12), sin(i * TAU / 12)) * 4.6
		var pebble := Art.sphere(
			world, Vector3(rim.x, terrain.height_at(rim) + 0.12, rim.y), 0.28, Color("7f8e7d")
		)
		pebble.scale = Vector3(1.3, 0.65, 0.9)
	var waterfall2: Vector2 = Vector2(-17, 30).normalized() * (terrain.radius(atan2(30, -17)) - 0.3)
	var top: float = terrain.height_at(waterfall2)
	for i in range(3):
		Art.box(
			world,
			Vector3(waterfall2.x + i * 0.6, top - 12, waterfall2.y),
			Vector3(0.52, 25, 0.3),
			Color("87c5c9")
		)


func add_object(
	id: String, node: Node3D, kind: String, at: Vector3, radius: float = 2.2, value: int = 0
) -> void:
	objects.append(
		{
			"id": id,
			"node": node,
			"kind": kind,
			"base": at,
			"radius": radius,
			"value": value,
			"near": false
		}
	)


func build_collectibles() -> void:
	# Deterministic resource receipts are independent from v0.9.0 coin IDs.
	for i in range(12):
		var resource: String = ["wood", "crystal", "herbs"][i % 3]
		var id := "resource_%d" % i
		if id in store.memory().picked:
			continue
		var route: Array = terrain.paths[i % 2]
		var p: Vector2 = route[0].lerp(route[1], 0.28 + i * 0.04)
		if terrain.layout_version >= 2:
			var segment := 1 + int(i / 4) % (route.size() - 2)
			p = route[segment].lerp(route[segment + 1], 0.22 + (i % 4) * 0.16)
		p += Vector2(-1.8 if i % 2 == 0 else 1.8, 0)
		var node := Node3D.new()
		world.add_child(node)
		node.position = Vector3(p.x, terrain.height_at(p), p.y)
		match resource:
			"wood":
				for j in range(3):
					var log := Art.cone(
						node,
						Vector3((j - 1) * 0.22, 0.2 + (0.16 if j == 1 else 0.0), 0),
						0.13,
						0.13,
						0.7,
						Color("8c572d")
					)
					log.rotation.x = PI / 2
					var cut := Art.cone(
						node,
						Vector3((j - 1) * 0.22, 0.2 + (0.16 if j == 1 else 0.0), 0.36),
						0.11,
						0.11,
						0.025,
						Color("edc17c")
					)
					cut.rotation.x = PI / 2
			"crystal":
				for j in range(3):
					var crystal := Art.cone(
						node,
						Vector3((j - 1) * 0.18, 0.25 + j * 0.07, 0),
						0.14,
						0,
						0.5 + j * 0.14,
						Color("29dffa")
					)
					crystal.rotation.z = (j - 1) * 0.22
			"herbs":
				Art.cone(node, Vector3(0, 0.3, 0), 0.035, 0.025, 0.6, Color("579b55"))
				for j in range(3):
					var leaf := Art.sphere(
						node,
						Vector3(cos(j * TAU / 3) * 0.17, 0.3 + j * 0.09, sin(j * TAU / 3) * 0.17),
						0.23,
						Color("80e65e")
					)
					leaf.scale = Vector3(0.55, 0.3, 1.3)
					leaf.rotation.y = -j * TAU / 3
				Art.sphere(node, Vector3(0, 0.7, 0), 0.12, Color("e4a1ff"), 0.5)
		Art.loot_ray(node, [Color("ffbd4f"), Color("37dcff"), Color("a1ff61")][i % 3], 1.6)
		add_object(id, node, "resource", node.position + Vector3.UP * 0.6, 2.5, i % 3)
	var count := 0
	for route in terrain.paths:
		for i in range(route.size() - 1):
			for j in range(1, 5):
				var p: Vector2 = route[i].lerp(route[i + 1], float(j) / 5)
				var id := "coin_%d" % count
				count += 1
				if id in store.memory().picked:
					continue
				var n := Node3D.new()
				world.add_child(n)
				n.position = Vector3(p.x, terrain.height_at(p) + 1.0, p.y)
				var coin := Art.cone(n, Vector3.ZERO, 0.28, 0.28, 0.12, Color("ffd347"), 0.55)
				coin.rotation_degrees.x = 90
				add_object(id, n, "coin", n.position, 1.5)
	if use_expeditions:
		return
	for i in range(3):
		if i in store.memory().seeds:
			continue
		var n := Node3D.new()
		world.add_child(n)
		var at: Vector3 = (
			terrain.point("ruins") + Vector3(0, 1.2, -2)
			if i == 0
			else (Vector3(0, 1.5, -161) if i == 1 else terrain.point("ridge") + Vector3(0, 1.3, -1))
		)
		n.position = at
		Art.cone(n, Vector3(0, 0.3, 0), 0.42, 0, 0.8, Color("c2e1b5"))
		Art.cone(n, Vector3(0, -0.3, 0), 0, 0.42, 0.8, Color("88c9b1"))
		add_object("seed_%d" % i, n, "seed", at, 2.7, i)


func build_cave() -> void:
	var cave := Node3D.new()
	world.add_child(cave)
	var rock := Color("4b6074")
	Art.box(cave, Vector3(0, -0.5, -150), Vector3(20, 1, 30), Color("66717d"), true)
	for side in [-1, 1]:
		Art.box(cave, Vector3(side * 10, 4, -150), Vector3(1, 8, 30), rock, true)
	Art.box(cave, Vector3(0, 4, -165), Vector3(20, 8, 1), rock, true)
	Art.box(cave, Vector3(0, 8, -150), Vector3(20, 0.7, 30), rock, true)
	Art.box(cave, Vector3(0, 4, -135), Vector3(20, 8, 1), rock, true)
	Art.label(
		cave, "SUBTERRANEAN ARCHIVE" if use_expeditions else "ECHO CAVERN", Vector3(0, 6.8, -163)
	)
	var names := ["I", "II", "III"] if use_expeditions else ["SUN", "MOON", "STAR"]
	var clue := (
		"%s → %s → %s" % [names[cave_sequence[0]], names[cave_sequence[1]], names[cave_sequence[2]]]
	)
	Art.label(
		cave,
		("ACCESS FREQUENCY\n" if use_expeditions else "THE ANCIENT SONG\n") + clue,
		Vector3(0, 4, -155),
		Color("dce2bd")
	)
	for i in range(3):
		var n := Node3D.new()
		cave.add_child(n)
		n.position = Vector3((i - 1) * 5, 0, -153)
		Art.cone(n, Vector3(0, 0.6, 0), 0.8, 0.6, 1.2, rock)
		var lamp := Art.sphere(n, Vector3(0, 1.7, 0), 0.45, Color("acc8de"), 0.7)
		cave_lamps.append(lamp)
		Art.label(n, names[i], Vector3(0, 3, 0))
		add_object("rune_%d" % i, n, "rune", n.position + Vector3.UP, 2.5, i)
	var exit := Node3D.new()
	cave.add_child(exit)
	exit.position = Vector3(0, 0, -138)
	Art.label(exit, "DAYLIGHT →", Vector3(6.5, 2.5, 0))
	add_object("exit", exit, "exit_cave", exit.position + Vector3.UP, 3.2)
	for i in range(12):
		var at := Vector3(-8 if i % 2 == 0 else 8, 0.8, -138 - i * 2)
		Art.cone(cave, at, 0.45, 0, 1.6, Color("9fc2d1"))
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 5, -150)
	glow.omni_range = 22
	glow.light_color = Color("b4dbe8")
	glow.light_energy = 2.5
	cave.add_child(glow)


func build_sky() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1903
	for i in range(18):
		var angle := float(i) * TAU / 18
		var distance := rng.randf_range(75, 135)
		var cloud := Node3D.new()
		world.add_child(cloud)
		cloud.position = Vector3(
			cos(angle) * distance, rng.randf_range(-8, 22), sin(angle) * distance
		)
		for j in range(3):
			var part := Art.sphere(
				cloud, Vector3((j - 1) * 4, 0, 0), rng.randf_range(3, 6), Color("d1dfd6")
			)
			part.scale.y = 0.4
		cloud.set_meta("distant", true)
	for i in range(4):
		var n := Node3D.new()
		world.add_child(n)
		n.position = Vector3(-95 + i * 60, -10 - i * 3, -100)
		Art.cone(n, Vector3.ZERO, 1, 12, 18, Color("78999c"))
		Art.cone(n, Vector3(0, 9, 0), 12, 12, 1, Color("a0b7a1"))
		n.set_meta("distant", true)


func island_name(index: int = -1) -> String:
	if index < 0:
		index = int(store.data.island)
	return Terrain.NAMES[index % Terrain.NAMES.size()]


func start_game(show_contract: bool = true) -> void:
	playing = true
	player.arm.spring_length = 9.5
	player.yaw = 0
	if use_expeditions and expedition != null:
		var toward: Vector3 = expedition.target() - player.position
		player.yaw = atan2(-toward.x, -toward.z)
		player.body.rotation.y = player.yaw
	player.pitch = -0.36
	player.pivot.rotation = Vector3(player.pitch, player.yaw, 0)
	hud.show_game()
	tell(
		(
			expedition.instruction()
			if use_expeditions
			else "Find the lost cloud at the ruins. Follow the golden trail."
		)
	)

	if show_contract:
		brief_if_new()


func pause_game() -> void:
	playing = false
	player.reset_controls()
	mouse_drag = false
	mouse_stick = false
	hud.show_pause()


func resume_game() -> void:
	playing = true
	hud.show_game()


func return_lobby() -> void:
	playing = false
	player.eye_equipment.visible = false
	player.cameras.mode = 0
	player.cameras.aiming = false
	player.cameras.reveal_remaining = 0
	player.body.visible = true
	player.pivot.position = Vector3(0, 1.65, 0)
	player.pitch = -0.32
	player.pivot.rotation.x = player.pitch
	if in_cave:
		leave_cave()
	player.reset_controls()
	player.arm.spring_length = 16
	hud.show_lobby()


func select_island(index: int) -> void:
	if index < 0 or index > int(store.data.unlocked):
		return
	if store.transact(func(): store.data.island = index):
		build_world()
		hud.show_lobby()
	else:
		tell(store.last_error)


func save_setting(key: String, value: Variant) -> void:
	if not store.transact(func(): store.data[key] = value):
		tell(store.last_error)
	apply_quality()
	sound.set_volume(float(store.data.volume))


func apply_quality() -> void:
	get_viewport().msaa_3d = (
		Viewport.MSAA_2X if int(store.data.quality) == 1 else Viewport.MSAA_DISABLED
	)
	light.shadow_enabled = int(store.data.quality) == 1
	for detail in get_tree().get_nodes_in_group("polish_detail"):
		detail.visible = int(store.data.quality) == 1
	for child in world.get_children():
		if child.has_meta("distant"):
			child.visible = int(store.data.quality) == 1


func action(id: String) -> void:
	if not playing:
		return
	match id:
		"camera_mode":
			player.cameras.cycle()
		"crouch":
			player.toggle_crouch()
		"aim":
			player.cameras.aiming = not player.cameras.aiming
		"shoulder":
			player.cameras.shoulder *= -1
		"jump":
			player.request_jump()
		"attack":
			player.attack()
		"dash":
			player.dash()
		"sprint":
			player.sprinting = not player.sprinting
		"bag":
			open_bag()
		"weapon":
			if store.equip(next_weapon()):
				player.refresh_weapon()
			else:
				tell("Craft a bow at camp to unlock ranged combat.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if playing:
			pause_game()
		elif hud.page == "pause" or hud.page == "bag":
			resume_game()
		return
	if not playing:
		return
	for control in ["camera_mode", "crouch", "aim", "shoulder"]:
		if event.is_action_pressed(control):
			action(control)
	if event.is_action_pressed("bag"):
		open_bag()
		return
	if event.is_action_pressed("weapon"):
		action("weapon")
	if event.is_action_pressed("jump"):
		player.request_jump()
	if event.is_action_pressed("attack"):
		player.attack()
	if event.is_action_pressed("dash"):
		player.dash()
	if event.is_action_pressed("interact"):
		interact()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			var local: Vector2 = (event.position - hud.position) / hud.unit
			if event.pressed and local.distance_to(Vector2(150, 575)) < 120:
				mouse_stick = true
				hud.set_stick(local)
			elif event.pressed:
				mouse_drag = true
			else:
				mouse_drag = false
				mouse_stick = false
				player.stick = Vector2.ZERO
				hud.stick_delta = Vector2.ZERO
				hud.queue_redraw()
	if event is InputEventMouseMotion:
		if mouse_stick:
			hud.set_stick((event.position - hud.position) / hud.unit)
		elif mouse_drag:
			player.look(event.relative / hud.unit)


func nearest() -> Dictionary:
	var result: Dictionary = {}
	var best := 10000.0
	for object in objects:
		if not is_instance_valid(object.node) or not object.node.visible or object.kind == "coin":
			continue
		if object.kind == "cloud" and store.memory().cloud:
			continue
		if object.kind == "resource" and store.weight() + 2 > store.capacity():
			continue
		var distance: float = player.position.distance_to(object.base)
		if use_expeditions and object.kind == "expedition":
			distance = maxf(0.0, distance - 0.4)
		if distance < float(object.radius) and distance < best:
			best = distance
			result = object
	return result


func interaction_prompt() -> String:
	var obj := nearest()
	if obj.is_empty():
		return ""
	match obj.kind:
		"field_cache":
			return "E  •  OPEN FIELD CACHE"
		"expedition":
			return (
				"E  •  "
				+ (
					"CALIBRATE RELAY"
					if expedition.kind == 0
					else ("OPEN ARCHIVE" if expedition.kind == 1 else "SECURE OUTPOST")
				)
			)
		"ground":
			return "E  •  OPEN DROPPED LOOT"
		"resource":
			return "E  •  GATHER " + ["WOOD", "CRYSTAL", "HERBS"][obj.value]
		"cloud":
			return "E  •  FREE THE CLOUD"
		"camp":
			return "E  •  REST AT CAMP"
		"enter_cave":
			return "E  •  ENTER ECHO CAVERN"
		"exit_cave":
			return "E  •  RETURN TO DAYLIGHT"
		"rune":
			return (
				"E  •  TUNE TERMINAL " + ["I", "II", "III"][obj.value]
				if use_expeditions
				else "E  •  SING " + ["SUN", "MOON", "STAR"][obj.value]
			)
		"seed":
			return "E  •  GATHER SKYSEED"
		"beacon":
			return "E  •  TRAVEL ONWARD" if store.memory().restored else "E  •  RESTORE THE BEACON"
	return ""


func objective() -> String:
	if use_expeditions and expedition != null:
		return expedition.objective()
	var memory := store.memory()
	var target: Vector3
	var caption: String
	if in_cave:
		return (
			"ECHO CAVERN  /  Sing the ancient song"
			if not memory.cave
			else "ECHO CAVERN  /  Gather the skyseed, then return"
		)
	if memory.restored:
		caption = "A NEW HORIZON  /  Step through the beacon"
		target = terrain.point("gate")
	elif not memory.cloud:
		caption = "A LITTLE KINDNESS  /  Free the cloud at the ruins"
		target = terrain.point("ruins")
	elif not 0 in memory.seeds:
		caption = "THE CLOUD'S GIFT  /  Gather the ruins skyseed"
		target = terrain.point("ruins")
	elif not 1 in memory.seeds:
		caption = "THE ANCIENT SONG  /  Explore Echo Cavern"
		target = terrain.point("cave")
	elif not 2 in memory.seeds:
		caption = "THE RIDGE WARDEN  /  Strike, dodge and gather"
		target = terrain.point("ridge")
	else:
		caption = "A LIGHT IN THE SKY  /  Restore the beacon"
		target = terrain.point("gate")
	nav_marker.position = target + Vector3(0, 5.5 + sin(clock * 2) * 0.4, 0)
	return caption + "  •  %dm" % int(player.position.distance_to(target))


func interact() -> void:
	if not playing:
		return
	var object := nearest()
	if object.is_empty():
		return
	interact_object(object)


func interact_object(object: Dictionary) -> void:
	var memory := store.memory()
	if use_expeditions and object.kind == "beacon":
		expedition.extract()
		return
	match object.kind:
		"field_cache":
			if object.id in memory.picked:
				return
			if store.transact(
				func():
					store.memory().picked.append(object.id)
					store.data.coins += 15
					var ammo := "bullets" if store.data.bag.get("gun", false) else "arrows"
					var room := maxi(0, floori((store.capacity() - store.weight()) * 10))
					store.data.bag[ammo] = mini(200, store.item_count(ammo) + mini(8, room))
			):
				object.node.visible = false
				celebrate_pickup(object.base, Color("ffc14c"))
				sound.cue(1300, 0.2, 0.14)
				tell(
					"FIELD CACHE • +15 Starlight and ammunition if space allows. Fund pack upgrades at camp."
				)
			else:
				tell(store.last_error)
		"expedition":
			expedition.interact(int(object.value))
		"ground":
			open_bag()
			hud.bag_tab = "nearby"
			hud.show_bag()
		"resource":
			if store.gather(object.id, ["wood", "crystal", "herbs"][object.value]):
				object.node.visible = false
				sound.cue(700, 0.15, 0.1)
				tell("Materials packed. Return to camp to craft equipment.")
			else:
				tell(store.last_error)
		"camp":
			player.health = player.max_health
			player.stamina = 100
			tell("Rested and ready. No discoveries are lost when you fall.")
		"cloud":
			if store.transact(func(): store.memory().cloud = true):
				cloud_node.visible = false
				tell("Pip is free! Your new companion reveals a skyseed in the ruins.")
				sound.cue(784, 0.3, 0.15)
			else:
				tell(store.last_error)
		"enter_cave":
			enter_cave()
		"exit_cave":
			leave_cave()
		"rune":
			sing_rune(int(object.value))
		"seed":
			var id: int = object.value
			if id == 0 and not memory.cloud:
				tell("A kind act will awaken this seed. Free the cloud nearby.")
				return
			if id == 1 and not memory.cave:
				tell("The cavern remembers a song. Follow the three symbols above.")
				return
			if id == 2 and not guardian_defeated:
				tell("The warden protects this seed. Watch its windup, then dodge and strike.")
				return
			if store.collect(object.id, 5, id):
				object.node.visible = false
				tell("Skyseed found! %d / 3  •  +5 Starlight" % store.memory().seeds.size())
				sound.cue(880, 0.25, 0.14)
			else:
				tell(store.last_error)
		"beacon":
			if memory.restored:
				travel_next()
			elif memory.seeds.size() < 3 or not memory.cloud:
				tell("The beacon needs three skyseeds and the friendship of a cloud.")
			elif store.transact(
				func():
					store.memory().restored = true
					store.data.unlocked = maxi(int(store.data.unlocked), int(store.data.island) + 1)
					store.data.coins += 30
			):
				tell("ISLAND RESTORED  •  +30 Starlight. A new horizon is waiting.")
				sound.cue(1046, 0.5, 0.15)
				celebrate()
				player.cameras.reveal(terrain.point("gate"))
			else:
				tell(store.last_error)


func sing_rune(id: int) -> void:
	if store.memory().cave:
		tell("The cavern is awake. Its skyseed waits beyond the songstones.")
		return
	sound.cue([523, 659, 784][id], 0.3, 0.15)
	if id != cave_sequence[cave_steps.size()]:
		cave_steps.clear()
		for lamp in cave_lamps:
			lamp.scale = Vector3.ONE
		tell(
			(
				"Frequency mismatch. Restart the displayed sequence."
				if use_expeditions
				else "An echo fades. Begin the song again, from the first symbol."
			)
		)
		return
	cave_steps.append(id)
	cave_lamps[id].scale = Vector3.ONE * 1.5
	if cave_steps.size() == 3:
		if store.transact(func(): store.memory().cave = true):
			tell(
				(
					"Vault decoded. Open the gold archive chest."
					if use_expeditions
					else "The ancient song returns. The cavern's skyseed is awake."
				)
			)
		else:
			cave_steps.clear()
			tell(store.last_error)
	else:
		tell("The cavern answers… %d / 3" % cave_steps.size())


func enter_cave() -> void:
	in_cave = true
	player.position = Vector3(0, 0.3, -141)
	player.reset_controls()
	player.yaw = 0
	player.pitch = -0.32
	player.pivot.rotation = Vector3(player.pitch, 0, 0)
	player.arm.spring_length = 6.5
	tell(
		(
			"Decode the numbered terminals. Follow the cyan guide."
			if use_expeditions
			else "Read the ancient song. Sing each symbol at its songstone."
		)
	)


func leave_cave() -> void:
	in_cave = false
	player.position = terrain.point("cave") + Vector3(0, 0.5, 4)
	player.position.y = terrain.height_at(Vector2(player.position.x, player.position.z)) + 0.5
	player.reset_controls()
	player.arm.spring_length = 9.5


func travel_next() -> void:
	var next := int(store.data.island) + 1
	if next > int(store.data.unlocked):
		return
	if store.transact(func(): store.data.island = next):
		build_world()
		hud.show_game()
		brief_if_new()
		tell(
			(
				expedition.instruction()
				if use_expeditions
				else "A new chapter: " + island_name() + ". What will you discover?"
			)
		)
	else:
		tell(store.last_error)


func craft_tonic() -> void:
	if player.health >= player.max_health:
		tell("Already at full health. Camp also restores health for free.")
		return
	if int(store.data.coins) < 5:
		tell("Gather five Starlight, or return to camp to rest for free.")
		return
	if store.transact(func(): store.data.coins -= 5):
		player.health = minf(player.max_health, player.health + 55)
		tell("A warm tonic restores 55 health.")
	else:
		tell(store.last_error)


func respawn() -> void:
	player.burn_time = 0
	player.slow_time = 0
	player.stun_time = 0
	player.cameras.reveal_remaining = 0
	if in_cave:
		leave_cave()
	player.position = terrain.point("camp") + Vector3(0, 0.5, 3)
	player.position.y = terrain.height_at(Vector2(player.position.x, player.position.z)) + 0.5
	player.reset_controls()
	player.health = player.max_health
	player.stamina = 100
	player.invulnerable = 2
	tell("Back at camp. All discoveries and Starlight are safe.")


func strike(at: Vector3, forward: Vector3, damage: int) -> void:
	sound.cue(240, 0.1, 0.07)
	for enemy in enemies:
		var offset: Vector3 = enemy.position + Vector3.UP - at
		if enemy.visible and offset.length() < 3.4 and forward.dot(offset.normalized()) > -0.1:
			var query := PhysicsRayQueryParameters3D.create(at, enemy.position + Vector3.UP, 1)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				enemy.hit(damage, forward)
	var impact := Node3D.new()
	world.add_child(impact)
	impact.position = at + forward * 1.3
	for i in range(5):
		var spark := Art.box(
			impact,
			Vector3((i - 2) * 0.12, sin(i * 2.0) * 0.25, 0),
			Vector3(0.035, 0.2, 0.035),
			Color("ffe6a1")
		)
		spark.rotation.z = i * 0.8
	effects.append({"node": impact, "time": 0.15})


func open_bag() -> void:
	playing = false
	player.reset_controls()
	mouse_drag = false
	mouse_stick = false
	hud.show_bag()


func at_workbench() -> bool:
	return not in_cave and player.position.distance_to(terrain.point("camp")) < 6


func craft_item(recipe: String) -> void:
	if not at_workbench():
		tell("Crafting needs the workbench at camp.")
		return
	if store.craft(recipe):
		hud.show_bag()
		tell("Crafted " + recipe + ".")
		sound.cue(800, 0.2, 0.1)
	else:
		tell(store.last_error)


func use_tonic() -> void:
	if player.health >= player.max_health or store.data.bag.tonic <= 0:
		tell("A tonic needs missing health and one bottle in your bag.")
		return
	if store.transact(func(): store.data.bag.tonic -= 1):
		player.health = minf(player.max_health, player.health + 55)
		hud.show_bag()
		tell("Tonic used. Restored 55 health.")
	else:
		tell(store.last_error)


func fire_arrow() -> bool:
	if world.get_tree().get_nodes_in_group("arrows").size() >= 24:
		return false
	var using_gun: bool = int(store.data.bag.weapon) == 2
	var ammo := "bullets" if using_gun else "arrows"
	if store.item_count(ammo) <= 0:
		tell("Ammo empty. Craft " + ammo + " at camp.")
		return false
	var at: Vector3 = player.position + Vector3.UP * 1.3
	var forward: Vector3 = (
		player.cameras.forward()
		if player.cameras.aiming or player.cameras.mode in [1, 2]
		else -player.body.global_basis.z
	)
	var direction := forward
	if player.cameras.aiming or player.cameras.mode in [1, 2]:
		var eye: Vector3 = player.camera.global_position
		var aim_point: Vector3 = eye + forward * 50
		var sight := PhysicsRayQueryParameters3D.create(eye, aim_point, 5)
		var hit := get_world_3d().direct_space_state.intersect_ray(sight)
		if not hit.is_empty():
			aim_point = hit.position
		direction = (aim_point - at).normalized()
	var closest := 23.0
	# Friendly aim assist stays within the facing cone and checks solid scenery.
	for enemy in enemies:
		var offset: Vector3 = enemy.position + Vector3.UP - at
		if (
			enemy.health > 0
			and offset.length() < closest
			and not player.cameras.aiming
			and forward.dot(offset.normalized()) > 0.5
		):
			var query := PhysicsRayQueryParameters3D.create(at, at + offset, 1)
			if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				closest = offset.length()
				direction = offset.normalized()
	if not store.transact(func(): store.data.bag[ammo] -= 1):
		tell(store.last_error)
		return false
	var arrow := Arrow.new()
	world.add_child(arrow)
	arrow.add_to_group("arrows")
	arrow.setup(self, at, direction, using_gun)
	sound.cue(160 if using_gun else 510, 0.09, 0.1)
	return true


func celebrate() -> void:
	for i in range(20):
		var n := Node3D.new()
		world.add_child(n)
		n.position = beacon.position + Vector3(sin(i * 2.4) * 4, 2 + (i % 5), cos(i * 2.4) * 4)
		Art.sphere(n, Vector3.ZERO, 0.18, Color("f7dda0"), 1.0)
		effects.append({"node": n, "time": 2.0 + i * 0.05})


func tell(caption: String) -> void:
	if is_instance_valid(hud):
		hud.tell(caption)


func _process(dt: float) -> void:
	clock += dt
	for i in range(pickup_effects.size() - 1, -1, -1):
		var effect: Dictionary = pickup_effects[i]
		if not is_instance_valid(effect.node):
			pickup_effects.remove_at(i)
			continue
		if playing:
			effect.time -= dt
			effect.node.position.y += dt * 0.7
			effect.node.scale += Vector3.ONE * dt * 2
		if effect.time <= 0:
			effect.node.queue_free()
			pickup_effects.remove_at(i)
	for label in get_tree().get_nodes_in_group("landmark_labels"):
		label.visible = playing
	if not is_instance_valid(player):
		return
	if not playing:
		nav_marker.visible = false
		if is_instance_valid(hud) and hud.page in ["lobby", "heroes"]:
			player.yaw += dt * 0.065
			player.pivot.rotation.y = player.yaw
		return
	for object in objects:
		if object.kind == "ground" and is_instance_valid(object.node):
			object.node.visible = (
				store.memory().ground.has(object.id)
				and store.memory().ground[object.id].cave == in_cave
			)
	if use_expeditions and expedition != null:
		expedition.tick(dt)
	nav_marker.visible = not in_cave
	nav_marker.rotation.y += dt
	proximity_timer -= dt
	pickup_clock -= dt
	auto_collect(dt)
	for object in objects:
		if not is_instance_valid(object.node) or not object.node.visible:
			continue
		if object.kind == "coin" or object.kind == "seed":
			object.node.rotation.y += dt * 1.7
			if not object.get("pulling", false):
				object.node.position.y = object.base.y + sin(clock * 2 + object.base.x) * 0.18
			var distance: float = player.position.distance_to(object.node.position)
			if distance < 4 and not object.near:
				object.near = true
				if proximity_timer <= 0:
					sound.cue(660 if object.kind == "coin" else 990, 0.08, 0.05)
					proximity_timer = 0.4

	cloud_node.visible = not use_expeditions and not store.memory().cloud
	companion.visible = not use_expeditions and store.memory().cloud
	if companion.visible:
		var target: Vector3 = player.position + Vector3(1.8, 2.5 + sin(clock * 2) * 0.2, 1.4)
		if companion.position.distance_to(target) > 30:
			companion.position = target
		companion.position = companion.position.lerp(target, 1 - exp(-dt * 4))
		companion.rotation.y = player.body.rotation.y
	if store.memory().restored:
		portal.visible = true
		beacon.rotation.y = sin(clock * 0.4) * 0.025
	for i in range(effects.size() - 1, -1, -1):
		var effect: Dictionary = effects[i]
		effect.time -= dt
		effect.node.scale += Vector3.ONE * dt * 2
		if effect.time <= 0:
			effect.node.queue_free()
			effects.remove_at(i)
	if int(store.data.island) % 6 == 4 and not in_cave:
		var distance := (
			Vector2(player.position.x - lava_position.x, player.position.z - lava_position.z)
			. length()
		)
		if distance < 4.2 and player.position.y < lava_position.y + 0.7:
			player.hurt(27)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if playing and is_instance_valid(hud):
			pause_game()
		if is_instance_valid(sound):
			sound.music.stream_paused = true
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		if is_instance_valid(sound):
			sound.music.stream_paused = false
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


func can_collect(object: Dictionary) -> bool:
	if object.kind != "seed":
		return object.kind in ["coin", "resource", "drop"]
	var id: int = object.value
	return [store.memory().cloud, store.memory().cave, guardian_defeated][id]


func auto_collect(dt: float) -> void:
	for object in objects:
		if float(object.get("retry_at", 0.0)) > clock:
			continue
		if object.kind == "resource" and store.weight() + 2 > store.capacity():
			continue
		if not is_instance_valid(object.node) or not object.node.visible or not can_collect(object):
			continue
		var target: Vector3 = player.position + Vector3.UP * 0.9
		if object.node.global_position.distance_to(target) > 3.2:
			continue
		var ray := PhysicsRayQueryParameters3D.create(
			target, object.node.global_position + Vector3.UP * 0.35, 1
		)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		object.pulling = true
		object.node.global_position = object.node.global_position.move_toward(target, dt * 9)
		if object.node.global_position.distance_to(target) > 0.35:
			continue
		var committed := false
		match object.kind:
			"coin":
				committed = store.collect(object.id, 1)
			"resource":
				committed = store.gather(object.id, ["wood", "crystal", "herbs"][object.value])
			"seed":
				committed = store.collect(object.id, 5, object.value)
			"drop":
				committed = store.claim_drop(object.id, object.value == 1)
		if committed:
			celebrate_pickup(
				object.base, Color("ffd347") if object.kind == "coin" else Color("5df3ff")
			)
			object.node.visible = false
			sound.cue(880 if object.kind != "seed" else 1100, 0.08, 0.07)
		else:
			# Leave the item and retry slowly after failed saves / full inventory.
			object.node.position = object.base
			object.pulling = false
			object.retry_at = clock + 1.5
			if not store.last_error.is_empty():
				tell(store.last_error)


func spawn_drop(enemy) -> void:
	var id := "mob_drop_%d_%d" % [roundi(enemy.home.x * 10), roundi(enemy.home.z * 10)]
	if id in store.memory().picked:
		return
	for object in objects:
		if object.id == id:
			return
	var node := Node3D.new()
	world.add_child(node)
	node.position = enemy.position + Vector3.UP * 0.5
	Art.cone(node, Vector3.ZERO, 0.25, 0, 0.6, Color("9fe4e0"))
	add_object(id, node, "drop", node.position, 3, 1 if enemy.elite else 0)


func sync_ground() -> void:
	for object in objects:
		if object.kind == "ground" and is_instance_valid(object.node):
			object.node.visible = false
	for id in store.memory().ground:
		var entry: Dictionary = store.memory().ground[id]
		var existing := false
		for object in objects:
			if object.id == id and object.kind == "ground":
				object.node.visible = entry.cave == in_cave
				existing = true
		if existing:
			continue
		var node := Node3D.new()
		world.add_child(node)
		node.position = Vector3(entry.at[0], entry.at[1], entry.at[2])
		Art.box(node, Vector3.ZERO, Vector3(0.5, 0.4, 0.4), Color("a78552"))
		Art.box(node, Vector3(0, 0.05, 0), Vector3(0.52, 0.08, 0.42), Color("e6cc8f"))
		node.visible = entry.cave == in_cave
		add_object(id, node, "ground", node.position, 3)


func nearby_ground() -> Array:
	var result := []
	for id in store.memory().ground:
		var entry: Dictionary = store.memory().ground[id]
		var at := Vector3(entry.at[0], entry.at[1], entry.at[2])
		if entry.cave == in_cave and player.position.distance_to(at) < 4:
			var sight := PhysicsRayQueryParameters3D.create(
				player.position + Vector3.UP, at + Vector3.UP * 0.35, 1
			)
			if get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
				result.append(id)
	return result


func drop_inventory(item: String, amount: int) -> void:
	# Put the stack on the floor beneath the explorer, not in a wall or in mid-air.
	var floor_ray := PhysicsRayQueryParameters3D.create(
		player.position + Vector3.UP * 0.5, player.position - Vector3.UP * 5.0, 1
	)
	var floor_hit := get_world_3d().direct_space_state.intersect_ray(floor_ray)
	if floor_hit.is_empty():
		tell("Land on solid ground before dropping items.")
		return
	var drop_at: Vector3 = floor_hit.position + Vector3.UP * 0.3
	if store.drop_item(item, amount, drop_at, in_cave):
		player.refresh_weapon()
		sync_ground()
		hud.show_bag()
		tell("Dropped %d %s. Reclaim from NEARBY." % [amount, item])
	else:
		tell(store.last_error)


func reclaim_inventory(id: String) -> void:
	if id not in nearby_ground():
		return
	if store.reclaim(id):
		sync_ground()
		hud.show_bag()
		sound.cue(880, 0.08, 0.07)
	else:
		tell(store.last_error)


func next_weapon() -> int:
	for offset in range(1, 4):
		var candidate := (int(store.data.bag.weapon) + offset) % 3
		if (
			candidate == 0
			or (candidate == 1 and store.data.bag.bow)
			or (candidate == 2 and store.data.bag.get("gun", false))
		):
			return candidate
	return 0


func celebrate_pickup(at: Vector3, tint: Color) -> void:
	if pickup_effects.size() >= 8:
		return
	var effect := Node3D.new()
	world.add_child(effect)
	effect.position = at
	for i in range(6):
		var spark := Art.sphere(
			effect, Vector3(cos(i * TAU / 6) * 0.16, 0.3, sin(i * TAU / 6) * 0.16), 0.045, tint, 1.5
		)
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pickup_effects.append({"node": effect, "time": 0.35})


func buy_pack_upgrade() -> void:
	if not at_workbench():
		tell("Return to camp for a backpack upgrade.")
		return
	if store.upgrade_pack():
		hud.show_bag()
		tell("Backpack upgraded • +10 capacity. Your supplies stay with you.")
		sound.cue(1046, 0.3, 0.14)
	else:
		tell(store.last_error)


func brief_if_new() -> void:
	if use_expeditions and not store.memory().expedition.get("brief_seen", false):
		store.memory().expedition.brief_seen = true
		hud.show_brief()
