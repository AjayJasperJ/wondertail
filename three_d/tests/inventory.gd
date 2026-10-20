extends SceneTree
const Store = preload("res://scripts/save_store.gd")
var checks := 0
var failures := 0


func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize():
	call_deferred("run")


func run():
	var store := Store.new()
	store.path = "user://inventory_test_%d.json" % Time.get_ticks_usec()
	store.data.bag.wood = 12
	store.data.bag.crystal = 12
	store.data.bag.herbs = 4
	check(store.drop_item("wood", 3, Vector3(2, 1, 3), false), "Drop commits")
	check(
		store.data.bag.wood == 9 and store.memory().ground.size() == 1,
		"Drop removes exactly the requested amount"
	)
	var id: String = store.memory().ground.keys()[0]
	var copy := Store.new()
	copy.path = store.path
	check(copy.load_save() and copy.memory().ground.has(id), "Dropped loot survives reload")
	check(copy.reclaim(id) and copy.data.bag.wood == 12, "Reclaim restores dropped stack")
	check(not copy.reclaim(id) and copy.data.bag.wood == 12, "Reclaim cannot duplicate a stack")
	check(not copy.drop_item("wood", -2, Vector3.ZERO, false), "Negative quantities rejected")
	check(not copy.drop_item("wood", 99, Vector3.ZERO, false), "Excess quantities rejected")
	check(not copy.drop_item("sword", 1, Vector3.ZERO, false), "Starter fallback protected")
	check(
		(
			copy.drop_item("bow", 1, Vector3.ZERO, true)
			and not copy.data.bag.bow
			and copy.data.bag.weapon == 0
		),
		"Dropping equipped bow falls back to sword"
	)
	var bow_id: String = copy.memory().ground.keys()[0]
	check(copy.reclaim(bow_id) and copy.data.bag.bow, "Bow can be reclaimed")
	var previous: Dictionary = copy.data.duplicate(true)
	var writable := copy.path
	copy.path = "user://not_a_real_inventory_parent/save.json"
	check(
		not copy.drop_item("wood", 2, Vector3.ZERO, false) and copy.data == previous,
		"Failed drop rolls back inventory and ground"
	)
	copy.path = writable
	check(copy.drop_item("crystal", 3, Vector3.ZERO, false), "Prepare reclaim rollback")
	id = copy.memory().ground.keys()[0]
	previous = copy.data.duplicate(true)
	copy.path = "user://not_a_real_inventory_parent/save.json"
	check(
		not copy.reclaim(id) and copy.data == previous,
		"Failed reclaim preserves ground and inventory"
	)
	copy.path = writable
	check(copy.craft("gun") and copy.data.bag.gun, "Craft pistol")
	check(copy.craft("bullets") and copy.data.bag.bullets == 12, "Craft ammo")
	check(copy.equip(2), "Equip crafted pistol")
	check(
		copy.drop_item("gun", 1, Vector3.ZERO, false) and copy.data.bag.weapon == 0,
		"Dropping gun restores fallback"
	)
	check(Store.valid(copy.data), "New save schema validates")
	var legacy := Store.fresh()
	legacy.bag.erase("gun")
	legacy.bag.erase("bullets")
	check(Store.valid(legacy), "Old bags without gun fields validate")
	check(
		copy.grid_recipe(["wood", "", "", "", "", "", "", "", ""]) == "arrows",
		"Craft grid resolves arrows"
	)
	check(
		copy.grid_recipe(["wood", "wood", "wood", "crystal", "crystal", "", "", "", ""]) == "bow",
		"Craft grid resolves bow"
	)
	check(
		copy.grid_recipe(["wood", "herbs", "", "", "", "", "", "", ""]) == "",
		"Invalid grid has no output"
	)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.store = copy
	game.store.data = Store.fresh()
	game.store.data.bag.wood = 40
	game.store.data.bag.arrows = 0
	game.store.memory().cloud = true
	game.build_world()
	game.playing = true
	game.player.set_physics_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	for object in game.objects:
		object.node.visible = false
	game.player.position = Vector3(0, 15, 0)
	var resource := Node3D.new()
	game.world.add_child(resource)
	resource.position = Vector3(0, 15.9, 0)
	game.add_object("full_resource_test", resource, "resource", resource.position, 3, 0)
	var seed := Node3D.new()
	game.world.add_child(seed)
	seed.position = Vector3(0, 15.9, 0)
	game.add_object("required_seed_test", seed, "seed", seed.position, 3, 0)
	await physics_frame
	game.auto_collect(1)
	check(
		resource.visible and not seed.visible and 0 in game.store.memory().seeds,
		"Full resource pickup cannot starve quest seed"
	)
	check(game.store.drop_item("wood", 2, game.player.position, false), "Prepare ground visuals")
	game.sync_ground()
	check(game.nearby_ground().size() == 1, "Nearby stacks visible in current realm")
	game.in_cave = true
	check(game.nearby_ground().is_empty(), "Surface loot does not leak into cave")
	game.in_cave = false
	game.open_bag()
	await process_frame
	var buttons: Array = []
	for child in game.hud.widgets.get_children():
		if child is Button and child.visible:
			var rect := Rect2(child.position, child.size)
			check(
				Rect2(0, 0, 1280, 720).encloses(rect),
				"Inventory control stays in viewport: " + child.text
			)
			for other in buttons:
				check(
					not rect.intersects(Rect2(other.position, other.size)),
					(
						"Inventory controls do not overlap: "
						+ child.text
						+ str(rect)
						+ "/"
						+ other.text
						+ str(Rect2(other.position, other.size))
					)
				)
			buttons.append(child)
	for item in [game.player.sword, game.player.gun]:
		var bounds := AABB()
		var first := true
		for mesh in item.find_children("*", "MeshInstance3D", true, false):
			var local: AABB = (
				(item.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
			)
			bounds = local if first else bounds.merge(local)
			first = false
		var longest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		check(
			absf(longest - (1.0 if item == game.player.sword else 0.48)) < 0.01,
			"Weapon model keeps its intended size after import transforms"
		)
	game.store.data.bag.gun = true
	game.store.data.bag.bullets = 12
	game.store.equip(2)
	game.player.refresh_weapon()
	check(
		game.player.gun.visible and not game.player.bow.visible and not game.player.sword.visible,
		"Equipped gun visibility"
	)
	game.playing = true
	var ammo: int = game.store.data.bag.bullets
	check(game.fire_arrow() and game.store.data.bag.bullets == ammo - 1, "Gun consumes gun ammo")
	game.queue_free()
	await process_frame
	print("INVENTORY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
