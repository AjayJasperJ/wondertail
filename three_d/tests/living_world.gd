extends SceneTree
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.store.data = game.store.fresh()
	game.store.path = "user://living_test_%d.json" % Time.get_ticks_usec()
	game.build_world()
	game.store.data.bag.wood = 6
	check(game.living.accept(0), "Accept optional delivery")
	check(not game.living.accept(1), "Cannot overwrite an active contract")
	check(game.living.claim(), "Deliver materials for currency")
	check(
		(
			game.store.data.bag.wood == 0
			and game.store.data.coins == 30
			and game.living.state().diamonds == 2
		),
		"Reward and costs commit together"
	)
	check(not game.living.claim() and game.store.data.coins == 30, "Claim cannot repeat")
	check(game.living.upgrade("workshop"), "Diamonds build a persistent workshop")
	check(not game.living.upgrade("workshop"), "Duplicate improvements rejected")
	check(
		game.living.purchase("arrows") and game.store.data.coins == 27,
		"Workshop discounts supply purchase"
	)
	var snapshot: Dictionary = game.store.data.duplicate(true)
	var path: String = game.store.path
	game.store.path = "user://missing_living_parent/save.json"
	check(
		not game.living.purchase("tonic") and game.store.data == snapshot,
		"Failed purchase rolls back"
	)
	game.store.path = path
	check(game.living.accept(4), "Accept rescue contract")
	check(not game.living.claim(), "Rescue must occur before payment")
	check(game.living.mark_encounter(game.living.encounter_id()), "Rescue discovery saved")
	check(
		game.living.claim() and game.living.state().completed == 2,
		"Rescue reward advances repeatable cycle"
	)
	var reloaded = game.Store.new()
	reloaded.path = path
	check(
		(
			reloaded.load_save()
			and reloaded.data.living.completed == 2
			and "workshop" in reloaded.data.living.camp
		),
		"Camp and contract progress survives reload"
	)
	game.store.data.antialiasing = 1
	game.apply_quality()
	check(game.get_viewport().msaa_3d == Viewport.MSAA_2X, "Mobile edge smoothing is enabled")
	game.playing = false
	var clock: float = game.clock
	game._process(2.0)
	check(game.clock == clock, "Menus pause the day-night cycle")
	game.hud.show_camp()
	game.queue_free()
	await process_frame
	print("LIVING WORLD: %d failures" % failures)
	quit(1 if failures else 0)
