extends SceneTree
const Store = preload("res://scripts/save_store.gd")
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for file in DirAccess.get_files_at("res://assets/models/shared"):
		if file.ends_with(".png"):
			var texture: Texture2D = load("res://assets/models/shared/" + file)
			check(texture.get_width() <= 256 and texture.get_height() <= 256, "External texture respects mobile size budget")
	var store := Store.new()
	store.path = "user://frontier_test_%d.json" % Time.get_ticks_usec()
	store.data.bag.wood = 50
	var boxes := store.weight()
	check(store.can_add("wood", 1), "A 51st item can open a second box")
	store.data.bag.wood = 51
	check(store.weight() == boxes + 1, "Identical items split at 50")
	store.data.bag.wood = 1250
	check(not store.can_add("wood", 1), "A full 27-box pack rejects a new stack")
	store.data.bag.wood = 1249
	check(store.can_add("wood", 1), "Full pack can top up an existing stack")
	store.data.bag.wood = 0
	check(store.gather("harvest_1", "wood"), "Harvest commits resources")
	check(not store.gather("harvest_1", "wood"), "Harvest cannot duplicate resources")
	var snapshot := store.data.duplicate(true)
	store.path = "user://missing_frontier_parent/save.json"
	check(
		not store.gather("harvest_2", "wood") and store.data == snapshot,
		"Failed harvest rolls back"
	)
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.playing = true
	var obj: Dictionary = {}
	for object in game.objects:
		if object.kind == "boat":
			obj = object
	check(obj.is_empty(), "Ocean-free world does not offer sailing into the void")
	game.store.data.quality = 0
	game.apply_quality()
	check(game.player.camera.far == 70.0, "Low detail limits the camera rendering horizon")
	check(game.environment.environment.fog_density > 0.02, "Fog covers the short rendering horizon")
	game.queue_free()
	await process_frame
	print("FRONTIER: %d failures" % failures)
	quit(1 if failures else 0)
