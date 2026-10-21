extends Control
const Minimap = preload("res://scripts/minimap.gd")
const ItemIcon = preload("res://scripts/item_icon.gd")
var game
var camera_label: Label
var hearts: RichTextLabel
var page := "lobby"
var widgets := Control.new()
var objective: Label
var quest_title: Label
var shoulder_button: Button
var view_button: Button
var vitals: Label
var notice: Label
var health: ProgressBar
var stamina: ProgressBar
var prompt: Button
var action_buttons: Dictionary = {}
var stick_id := -1
var look_id := -1
var run_id := -1
var touch_points: Dictionary = {}
var stick_delta := Vector2.ZERO
var message := ""
var message_time := 0.0
var unit := 1.0
var selected_item := "wood"
var pack_page := 0
var map_offset := 0
var level_points: Array[Vector2] = []
var bag_tab := "craft"
var craft_grid: Array = ["", "", "", "", "", "", "", "", ""]
var title_color := Color("f5cc83")


func setup(owner_game) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(widgets)
	widgets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 18
	var ui_font := SystemFont.new()
	ui_font.font_names = PackedStringArray(["DejaVu Sans", "Noto Sans", "Arial"])
	theme.default_font = ui_font
	for type in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("302b51") if type != "pressed" else Color("585282")
		style.border_color = Color("8f88bc")
		style.set_border_width_all(1)
		style.set_corner_radius_all(15)
		style.content_margin_left = 14
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		style.content_margin_right = 14
		theme.set_stylebox(type, "Button", style)
	theme.set_color("font_color", "Button", Color("e2f4f5"))
	theme.set_color("font_hover_color", "Button", Color("ffffff"))
	widgets.theme = theme
	get_viewport().size_changed.connect(resize)
	resize()
	show_lobby()


func resize() -> void:
	var viewport := get_viewport_rect().size
	unit = minf(viewport.x / 1280, viewport.y / 720)
	scale = Vector2.ONE * unit
	position = (viewport - Vector2(1280, 720) * unit) / 2
	queue_redraw()


func clear() -> void:
	reset_touch()
	for child in widgets.get_children():
		widgets.remove_child(child)
		child.queue_free()
	action_buttons.clear()
	queue_redraw()


func text(
	caption: String, at: Vector2, font_size: int = 20, color: Color = Color("f9edcf")
) -> Label:
	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	widgets.add_child(label)
	return label


func button(caption: String, rect: Rect2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.add_theme_font_size_override("font_size", 18)
	b.clip_text = true
	b.position = rect.position
	b.size = rect.size
	b.pressed.connect(callback)
	widgets.add_child(b)
	b.size = rect.size
	b.set_deferred("size", rect.size)
	return b


func decorate_item(slot: Button, item: String, amount: int, equipped: bool = false) -> void:
	slot.text = ""
	slot.tooltip_text = item.capitalize() + " • " + str(amount)
	var icon := ItemIcon.new()
	icon.item = item
	var icon_side := minf(44.0, slot.size.y - 25.0)
	icon.position = Vector2((slot.size.x - icon_side) * 0.5, 4)
	icon.size = Vector2.ONE * icon_side
	slot.add_child(icon)
	var quantity := Label.new()
	quantity.text = str(amount)
	quantity.position = Vector2(slot.size.x - (24 if amount < 10 else 35), slot.size.y - 24)
	quantity.add_theme_font_size_override("font_size", 16)
	quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(quantity)
	if equipped or selected_item == item:
		var style := slot.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		style.border_color = Color("ffd37e") if equipped else Color("7febd9")
		style.set_border_width_all(2)
		slot.add_theme_stylebox_override("normal", style)


func show_lobby() -> void:
	page = "lobby"
	game.world.visible = false
	clear()
	map_offset = maxi(0, (int(game.store.data.island) / 8) * 8)
	build_level_path()


func build_level_path() -> void:
	text("WONDERTAIL", Vector2(62, 48), 42, Color("fff1c7"))
	text("THE WANDERER'S TRAIL", Vector2(65, 105), 16, Color("b4b5ec"))
	text("Choose your next story", Vector2(65, 163), 25, Color("fff1e8"))
	text("ISLAND %02d" % (int(game.store.data.island) + 1), Vector2(65, 222), 30, Color("ffd178"))
	text(game.island_name(), Vector2(65, 270), 19, Color("e6def5"))
	text(
		(
			"%s\n%d coins • %d diamonds"
			% [
				game.store.HEROES[int(game.store.data.hero)],
				game.store.data.coins,
				game.living.state().diamonds
			]
		),
		Vector2(65, 315),
		18
	)
	button("CONTINUE  →", Rect2(65, 405, 315, 58), game.start_game)
	button("EXPLORERS", Rect2(65, 480, 150, 48), show_heroes)
	button("SETTINGS", Rect2(230, 480, 150, 48), show_settings)
	text("Offline. Your pace. Your world.", Vector2(65, 573), 16, Color("b6c7db"))
	text(
		"v" + str(ProjectSettings.get_setting("application/config/version")),
		Vector2(65, 650),
		13,
		Color("9baac4")
	)
	text("ISLAND JOURNEY", Vector2(465, 65), 23, Color("fff1d8"))
	level_points.clear()
	for i in range(8):
		var at := Vector2(510 + (i % 4) * 202, 275 if i < 4 else 485)
		if i >= 4:
			at.x = 1116 - (i % 4) * 202
		at.y += sin(i * 1.8) * 28
		level_points.append(at)
		var index := map_offset + i
		var unlocked: bool = index <= int(game.store.data.unlocked)
		var tier: int = game.Terrain.difficulty_for(index)
		var tint: Color = [Color("50cba0"), Color("55adf1"), Color("f0a45c"), Color("be86ef")][tier]
		var node := button(
			str(index + 1),
			Rect2(at - Vector2(36, 36), Vector2(72, 72)),
			func():
				if game.store.transact(func(): game.store.data.island = index):
					game.build_world()
					game.start_game()
				else:
					tell(game.store.last_error)
		)
		var style := StyleBoxFlat.new()
		style.bg_color = tint if unlocked else Color("44435f")
		style.border_color = (
			Color("fff0bb") if index == int(game.store.data.island) else tint.lightened(0.25)
		)
		style.set_border_width_all(4 if index == int(game.store.data.island) else 2)
		style.set_corner_radius_all(36)
		for state in ["normal", "hover", "pressed", "disabled"]:
			var feedback := style.duplicate() as StyleBoxFlat
			if state == "hover":
				feedback.bg_color = feedback.bg_color.lightened(0.12)
			elif state == "pressed":
				feedback.bg_color = feedback.bg_color.darkened(0.18)
			node.add_theme_stylebox_override(state, feedback)
		node.disabled = not unlocked
		node.tooltip_text = (
			game.island_name(index) + " • " + ["Relaxed", "Adventure", "Tough", "Extreme"][tier]
		)
		text(["RELAXED", "ADVENTURE", "TOUGH", "EXTREME"][tier], at + Vector2(-44, 46), 12, tint)
		var mechanic: String = ["RELAYS", "ARCHIVE", "SENTINELS"][(index + int(index / 3)) % 3]
		text(mechanic, at + Vector2(-39, 64), 11, Color("d8d1eb"))
	text(
		"GREEN: RELAXED   BLUE: ADVENTURE   AMBER: TOUGH   VIOLET: EXTREME",
		Vector2(465, 150),
		12,
		Color("c4cce0")
	)
	if map_offset > 0:
		button("← EARLIER", Rect2(465, 625, 190, 46), func(): show_atlas(map_offset - 8))
	button("MORE ISLANDS →", Rect2(970, 625, 240, 46), func(): show_atlas(map_offset + 8))


func header(title: String, subtitle: String) -> void:
	text(title, Vector2(100, 70), 40, title_color)
	text(subtitle, Vector2(102, 132), 19)
	button("← BACK", Rect2(100, 600, 180, 52), show_lobby)


func show_heroes() -> void:
	page = "heroes"
	clear()
	header("CHOOSE YOUR EXPLORER", "Three silhouettes. Three ways to travel.")
	var descriptions := [
		"ROWAN\nThe balanced explorer\n100 health · steady speed\nReliable double jump",
		"SKY\nThe agile scout\n80 health · fastest stride\nHighest double jump",
		"FERN\nThe mountain brawler\n135 health · heavy stride\nStrongest sword strike"
	]
	for i in range(3):
		var selected := "  ✓" if int(game.store.data.hero) == i else ""
		button(
			descriptions[i] + selected,
			Rect2(100 + i * 365, 215, 340, 280),
			func():
				if game.store.transact(func(): game.store.data.hero = i):
					game.rebuild_hero()
					show_heroes()
				else:
					tell(game.store.last_error)
		)


func show_atlas(offset: int = -1) -> void:
	page = "lobby"
	clear()
	map_offset = maxi(0, offset if offset >= 0 else int(game.store.data.island) / 8 * 8)
	build_level_path()


func show_settings() -> void:
	page = "settings"
	clear()
	header(
		"DISPLAY & SOUND",
		"Settings save immediately. FPS is a cap; device performance determines actual FPS."
	)
	text("MUSIC & SOUND", Vector2(100, 220), 23)
	var volume := HSlider.new()
	volume.position = Vector2(450, 224)
	volume.size = Vector2(540, 40)
	volume.min_value = 0
	volume.max_value = 1
	volume.step = 0.05
	volume.value = float(game.store.data.volume)
	volume.value_changed.connect(func(value): game.sound.set_volume(value))
	volume.drag_ended.connect(func(_changed): game.save_setting("volume", volume.value))
	widgets.add_child(volume)
	text("GRAPHICS", Vector2(100, 322), 23)
	button(
		["LOW", "MEDIUM", "HIGH", "ULTRA", "CUSTOM"][clampi(int(game.store.data.quality), 0, 4)],
		Rect2(450, 315, 300, 54),
		func():
			game.save_setting("quality", (int(game.store.data.quality) + 1) % 5)
			show_settings()
	)
	text("COLOR", Vector2(100, 510), 23)
	button(
		(
			"EDGE SMOOTHING "
			+ ["OFF", "2×", "4×"][clampi(int(game.store.data.get("antialiasing", 1)), 0, 2)]
		),
		Rect2(850, 450, 330, 48),
		func():
			game.save_setting("antialiasing", (int(game.store.data.get("antialiasing", 1)) + 1) % 3)
			show_settings()
	)
	if int(game.store.data.quality) == 4:
		button(
			"SHADOWS " + ("ON" if game.store.data.get("custom_shadows", true) else "OFF"),
			Rect2(850, 315, 330, 48),
			func():
				game.save_setting("custom_shadows", not game.store.data.get("custom_shadows", true))
				show_settings()
		)
		button(
			"RESOLUTION %.0f%%" % (100 * float(game.store.data.get("custom_scale", 1.0))),
			Rect2(850, 374, 330, 48),
			func():
				game.save_setting(
					"custom_scale",
					0.65 if float(game.store.data.get("custom_scale", 1.0)) >= 1.0 else 1.0
				)
				show_settings()
		)
	button(
		["NORMAL", "BALANCED", "REALISTIC", "COLORFUL", "PRO"][int(
			game.store.data.get("color_mode", 0)
		)],
		Rect2(450, 502, 300, 48),
		func():
			game.save_setting("color_mode", (int(game.store.data.get("color_mode", 0)) + 1) % 5)
			show_settings()
	)
	text("FPS LIMIT", Vector2(100, 580), 23)
	button(
		["LOW · 30", "MEDIUM · 45", "HIGH · 60", "EXTREME · 90", "MAX · 120"][int(
			game.store.data.get("fps_mode", 2)
		)],
		Rect2(450, 572, 300, 48),
		func():
			game.save_setting("fps_mode", (int(game.store.data.get("fps_mode", 2)) + 1) % 5)
			show_settings()
	)
	text("CAMERA SENSITIVITY", Vector2(100, 423), 23)
	button(
		"%.1f×  •  TAP TO CHANGE" % game.store.data.sensitivity,
		Rect2(450, 416, 370, 54),
		func():
			game.save_setting(
				"sensitivity",
				(
					0.5
					if float(game.store.data.sensitivity) >= 1.5
					else float(game.store.data.sensitivity) + 0.5
				)
			)
			show_settings()
	)


func bar(at: Vector2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = at
	b.size = Vector2(330, 10)
	b.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("243e46")
	background.set_corner_radius_all(5)
	var fill := background.duplicate()
	fill.bg_color = color
	b.add_theme_stylebox_override("background", background)
	b.add_theme_stylebox_override("fill", fill)
	widgets.add_child(b)
	b.size = Vector2(330, 10)
	return b


func show_game() -> void:
	page = "game"
	clear()
	quest_title = text("", Vector2(46, 34), 12, Color("a7cbb9"))
	objective = text("", Vector2(46, 57), 18, Color("f3edda"))
	objective.size = Vector2(540, 70)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button("BRIEF", Rect2(620, 26, 112, 48), show_brief)
	button("PAUSE", Rect2(972, 26, 88, 48), game.pause_game)
	button("PACK", Rect2(972, 106, 88, 48), game.open_bag)
	var radar := Minimap.new()
	radar.game = game
	radar.position = Vector2(1064, 18)
	widgets.add_child(radar)
	text("N", Vector2(1146, 16), 12, Color("b7cebd"))
	camera_label = text("", Vector2(1076, 195), 12, Color("d0ddd2"))
	button("TOOLS", Rect2(730, 84, 110, 44), func(): game.action("tool"))
	button(
		"CAMP",
		Rect2(850, 84, 110, 44),
		func():
			game.playing = false
			game.player.reset_controls()
			show_camp()
	)
	view_button = button("VIEW", Rect2(1104, 222, 120, 44), func(): game.action("camera_mode"))
	shoulder_button = button("L / R", Rect2(1006, 222, 78, 44), func(): game.action("shoulder"))
	hearts = RichTextLabel.new()
	hearts.position = Vector2(472, 599)
	hearts.size = Vector2(180, 32)
	hearts.bbcode_enabled = true
	hearts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hearts.add_theme_font_size_override("normal_font_size", 22)
	widgets.add_child(hearts)
	action_buttons["weapon"] = button(
		"SWAP", Rect2(650, 594, 170, 42), func(): game.action("weapon")
	)
	vitals = text("", Vector2(472, 637), 14, Color("dce3d4"))
	health = bar(Vector2(472, 664), Color("d8a583"))
	stamina = bar(Vector2(472, 679), Color("7db8a8"))
	notice = text("", Vector2(339, 484), 16, Color("ece8d4"))
	notice.size = Vector2(550, 42)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt = button("", Rect2(468, 547, 336, 42), game.interact)
	var entries := [
		["JUMP", Vector2(1150, 538), "jump"],
		["SHOOT", Vector2(1030, 592), "attack"],
		["DASH", Vector2(1150, 424), "dash"],
		["RUN", Vector2(911, 606), "sprint"],
		["CROUCH", Vector2(911, 495), "crouch"],
		["AIM", Vector2(1030, 480), "aim"]
	]
	for entry in entries:
		var action: String = entry[2]
		var size := Vector2(88, 88)
		if action == "attack":
			size = Vector2(100, 100)
		var control := button(entry[0], Rect2(entry[1], size), func(): game.action(action))
		action_buttons[action] = control
		control.add_theme_font_size_override("font_size", 13)
		for state in ["normal", "hover", "pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.06, 0.13, 0.15, 0.48 if state != "pressed" else 0.85)
			style.border_color = Color(0.8, 0.85, 0.74, 0.5)
			style.set_border_width_all(1)
			style.set_corner_radius_all(48 if action == "attack" else 40)
			style.content_margin_left = 0
			style.content_margin_right = 0
			style.content_margin_top = 0
			style.content_margin_bottom = 0
			control.add_theme_stylebox_override(state, style)
	# Keyboard hints live in Pause, leaving the playing field clear.


func show_bag() -> void:
	page = "bag"
	clear()
	var bag: Dictionary = game.store.data.bag
	header(
		"EXPEDITION PACK",
		"Select a stack. Equip, craft or drop it. Quest discoveries never use bag space."
	)
	for child in widgets.get_children():
		if child is Button and child.text == "← BACK":
			child.position = Vector2(1060, 68)
			child.pressed.disconnect(show_lobby)
			child.pressed.connect(game.resume_game)
	text(
		"PACK  •  %d / %d BOXES  •  50 PER STACK" % [game.store.weight(), game.store.capacity()],
		Vector2(80, 190),
		22,
		title_color
	)
	var items := ["wood", "crystal", "herbs", "arrows", "tonic", "bullets", "sword", "bow", "gun"]
	var stacks: Array = []
	for item in items:
		var remaining: int = game.store.item_count(item)
		while remaining > 0:
			stacks.append({"item": item, "amount": mini(50, remaining)})
			remaining -= mini(50, remaining)
	var boxes := maxi(int(game.store.capacity()), stacks.size())
	pack_page = clampi(pack_page, 0, maxi(0, ceili(float(boxes) / 27.0) - 1))
	for i in range(27):
		var index := pack_page * 27 + i
		var item: String = stacks[index].item if index < stacks.size() else ""
		var count: int = game.store.item_count(item)
		var equipped: bool = item == ["sword", "bow", "gun"][int(bag.weapon)]
		var slot := button(
			(
				(
					item.left(4).to_upper()
					+ ("*" if equipped else "")
					+ "\n"
					+ str(stacks[index].amount if index < stacks.size() else 0)
				)
				if item != ""
				else "·"
			),
			Rect2(80 + (i % 9) * 63, 238 + (i / 9) * 84, 59, 76),
			func():
				selected_item = item
				show_bag()
		)
		slot.add_theme_font_size_override("font_size", 10)
		if item != "":
			decorate_item(slot, item, int(stacks[index].amount), equipped)
		slot.disabled = item == ""
		if count == 0:
			slot.modulate = Color(0.65, 0.72, 0.72)
	if boxes > 27:
		button(
			"BOXES →",
			Rect2(460, 494, 178, 42),
			func():
				pack_page = (pack_page + 1) % ceili(float(boxes) / 27.0)
				show_bag()
		)
	text(
		selected_item.to_upper() + "  •  " + str(game.store.item_count(selected_item)) + " CARRIED",
		Vector2(80, 514),
		20
	)
	var action := button(
		"EQUIP" if selected_item in ["sword", "bow", "gun"] else "USE TONIC",
		Rect2(80, 554, 178, 50),
		func():
			if selected_item in ["sword", "bow", "gun"]:
				if game.store.equip(["sword", "bow", "gun"].find(selected_item)):
					game.player.refresh_weapon()
					show_bag()
				else:
					tell("Craft or pick up this weapon first.")
			else:
				game.use_tonic()
	)
	action.disabled = (
		selected_item not in ["sword", "bow", "gun", "tonic"]
		or game.store.item_count(selected_item) == 0
	)
	var one := button(
		"DROP ONE", Rect2(270, 554, 178, 50), func(): game.drop_inventory(selected_item, 1)
	)
	var stack := button(
		"DROP STACK",
		Rect2(460, 554, 178, 50),
		func(): game.drop_inventory(selected_item, mini(50, game.store.item_count(selected_item)))
	)
	one.disabled = selected_item == "sword" or game.store.item_count(selected_item) == 0
	stack.disabled = one.disabled
	text(
		"Starter sword stays in your pack as a fallback.\nSkyseeds and Starlight are protected discoveries.",
		Vector2(80, 627),
		16,
		Color("b5d6d2")
	)
	button(
		"CRAFTING",
		Rect2(730, 178, 210, 44),
		func():
			bag_tab = "craft"
			show_bag()
	)
	button(
		"NEARBY LOOT",
		Rect2(956, 178, 230, 44),
		func():
			bag_tab = "nearby"
			show_bag()
	)
	if bag_tab == "nearby":
		var nearby: Array = game.nearby_ground()
		text("DROPPED STACKS  •  WITHIN 4m", Vector2(730, 242), 18, title_color)
		if nearby.is_empty():
			text(
				"No dropped items nearby.\nDrop a stack to free space.\nIt stays here when you leave.",
				Vector2(730, 300),
				20
			)
		for i in range(mini(nearby.size(), 5)):
			var id: String = nearby[i]
			var entry: Dictionary = game.store.memory().ground[id]
			button(
				"PICK UP  •  %s × %d" % [String(entry.item).to_upper(), entry.amount],
				Rect2(730, 282 + i * 68, 456, 56),
				func(): game.reclaim_inventory(id)
			)
		if nearby.size() > 5:
			text("Pick up a stack to reveal more.", Vector2(730, 636), 17)
		return
	text(
		"CAMP TABLE" if game.at_workbench() else "CRAFT AT CAMP  •  PREVIEW ANYWHERE",
		Vector2(730, 238),
		17,
		title_color
	)
	for i in range(9):
		var index := i
		var ingredient: String = craft_grid[i]
		var slot := button(
			(
				("CRYST." if ingredient == "crystal" else ingredient.to_upper())
				if ingredient != ""
				else "+"
			),
			Rect2(730 + (i % 3) * 82, 274 + (i / 3) * 66, 74, 62),
			func():
				if craft_grid[index] != "":
					craft_grid[index] = ""
				elif (
					selected_item in ["wood", "crystal", "herbs"]
					and craft_grid.count(selected_item) < game.store.item_count(selected_item)
				):
					craft_grid[index] = selected_item
				show_bag()
		)
		slot.add_theme_font_size_override("font_size", 12)
		if ingredient != "":
			decorate_item(slot, ingredient, 1)
	var recipe: String = game.store.grid_recipe(craft_grid)
	var ready := recipe != ""
	var requirements: Array[String] = []
	if recipe != "":
		for item in game.store.RECIPES[recipe]:
			var needed: int = game.store.RECIPES[recipe][item]
			var carried: int = game.store.item_count(item)
			ready = ready and carried >= needed
			requirements.append("%s %d/%d" % [String(item).capitalize(), carried, needed])
	text(
		" • ".join(requirements) if recipe != "" else "Choose a recipe below",
		Vector2(730, 470),
		12,
		title_color if ready else Color("e8b5b5")
	)
	text("→", Vector2(990, 322), 32, title_color)
	var output := button(
		(
			(recipe.to_upper() if recipe != "" else "OUTPUT")
			+ (
				(
					" OWNED"
					if recipe in ["bow", "gun"] and game.store.item_count(recipe) > 0
					else " CRAFT"
				)
				if recipe != ""
				else " —"
			)
		),
		Rect2(1036, 370, 150, 46),
		func(): game.craft_item(recipe)
	)
	output.add_theme_font_size_override("font_size", 13)
	output.disabled = (
		recipe == ""
		or not ready
		or not game.at_workbench()
		or (recipe in ["bow", "gun"] and game.store.item_count(recipe) > 0)
	)
	if recipe != "":
		var preview := ItemIcon.new()
		preview.item = recipe
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.position = Vector2(1070, 276)
		preview.size = Vector2(80, 80)
		widgets.add_child(preview)
		text(
			(
				("PISTOL" if recipe == "gun" else recipe.to_upper())
				+ (" • AT CAMP" if not game.at_workbench() else "")
			),
			Vector2(1020, 252),
			14,
			title_color
		)
	button(
		"CLEAR GRID",
		Rect2(1036, 416, 150, 44),
		func():
			craft_grid.fill("")
			show_bag()
	)
	text("RECIPE BOOK  •  TAP TO FILL THE GRID", Vector2(730, 488), 17, title_color)
	var recipes := ["bow", "arrows", "tonic", "gun", "bullets"]
	for i in range(recipes.size()):
		var key: String = recipes[i]
		var label: String = {
			"bow": "BOW • 3W + 2C",
			"arrows": "8 ARROWS • 1W",
			"tonic": "TONIC • 2H + 1C",
			"gun": "PISTOL • 4W + 5C",
			"bullets": "12 ROUNDS • 1C"
		}[key]
		var book := button(
			label, Rect2(730 + (i % 2) * 234, 523 + (i / 2) * 50, 222, 42), select_recipe.bind(key)
		)
		book.add_theme_font_size_override("font_size", 13)
		book.name = "Recipe_" + key
	(
		button("+9 BOXES • 50 STARLIGHT", Rect2(964, 623, 222, 42), game.buy_pack_upgrade)
		. add_theme_font_size_override("font_size", 12)
	)
	text(
		"W: wood  C: crystal  H: herbs  •  Tap filled cells to clear",
		Vector2(730, 682),
		14,
		Color("b5d6d2")
	)


func select_recipe(recipe: String) -> void:
	if not game.store.RECIPES.has(recipe):
		return
	craft_grid.fill("")
	var cell := 0
	for item in game.store.RECIPES[recipe]:
		for count in range(game.store.RECIPES[recipe][item]):
			craft_grid[cell] = item
			cell += 1
	# Rebuild after the pointer event finishes, rather than deleting its button
	# during native web mouse/touch dispatch.
	show_bag.call_deferred()


func show_pause() -> void:
	page = "pause"
	clear()
	header(
		"TAKE A BREATH",
		"The world waits while this menu is open. Your discoveries are already saved."
	)
	button("RETURN TO THE TRAIL", Rect2(100, 220, 440, 62), game.resume_game)
	button("EXPEDITION BRIEF  •  OBJECTIVES & REWARD", Rect2(100, 305, 550, 62), show_brief)
	button("RETURN TO LOBBY", Rect2(100, 390, 440, 62), game.return_lobby)
	button("CAMP & CONTRACTS", Rect2(100, 475, 440, 62), show_camp)
	for child in widgets.get_children():
		if child is Button and child.text == "← BACK":
			child.pressed.disconnect(show_lobby)
			child.pressed.connect(game.return_lobby)


func show_camp() -> void:
	page = "camp"
	clear()
	var state: Dictionary = game.living.state()
	header(
		"THE LIVING CAMP",
		"Optional work. Explore the next island whenever you choose; no contract timer."
	)
	for child in widgets.get_children():
		if child is Button and child.text == "← BACK":
			child.position = Vector2(1060, 68)
			child.pressed.disconnect(show_lobby)
			child.pressed.connect(game.resume_game)
	text(
		"COINS %d   •   DIAMONDS %d" % [game.store.data.coins, state.diamonds],
		Vector2(100, 180),
		22,
		title_color
	)
	if state.active.is_empty():
		text("CHOOSE A REPEATABLE CONTRACT", Vector2(100, 230), 18)
		for i in range(game.living.TASKS.size()):
			var index := i
			button(
				game.living.TASKS[i],
				Rect2(100, 268 + i * 52, 540, 44),
				func(): game.camp_action("accept", str(index))
			)
	else:
		text(
			(
				game.living.TASKS[int(state.active.kind)]
				+ (
					"\nReward: %d coins + 2 diamonds\nProgress survives travel and reload."
					% (30 + int(state.active.kind) * 5)
				)
			),
			Vector2(100, 240),
			19
		)
		button(
			"DELIVER / CLAIM PAYMENT", Rect2(100, 350, 540, 48), func(): game.camp_action("claim")
		)
		button("ABANDON CONTRACT", Rect2(100, 410, 540, 42), func(): game.camp_action("abandon"))
	text(game.living.rumour(), Vector2(100, 535), 15, title_color)
	text("CAMP IMPROVEMENTS", Vector2(720, 230), 18, title_color)
	var names := ["workshop", "garden", "telescope", "forge", "storage"]
	for i in range(names.size()):
		var feature: String = names[i]
		var owned: bool = feature in state.camp
		var b := button(
			(
				feature.to_upper()
				+ (" • BUILT" if owned else " • %d DIAMONDS" % game.living.UPGRADES[feature])
			),
			Rect2(720, 268 + i * 44, 430, 38),
			func(): game.camp_action("upgrade", feature)
		)
		b.disabled = owned
	text("SUPPLIES • COINS", Vector2(720, 500), 17, title_color)
	var discount := 2 if "workshop" in state.camp else 0
	button(
		"8 ARROWS • %d" % (5 - discount),
		Rect2(720, 530, 210, 42),
		func(): game.camp_action("buy", "arrows")
	)
	button(
		"TONIC • %d" % (10 - discount),
		Rect2(945, 530, 205, 42),
		func(): game.camp_action("buy", "tonic")
	)
	button(
		"12 ROUNDS • %d" % (8 - discount),
		Rect2(720, 581, 210, 42),
		func(): game.camp_action("buy", "bullets")
	)
	button("EXPLORE NEXT ISLAND", Rect2(100, 605, 540, 48), func(): game.camp_action("explore"))
	text(
		"Workshop: cheaper supplies • Garden: herbs per contract\nForge: stronger melee • Storage: +9 boxes\nTelescope: reveals the island's field cache locations.",
		Vector2(720, 630),
		12
	)


func tell(caption: String) -> void:
	message = caption
	message_time = 5
	if page != "game":
		# Menu feedback is rendered in the game theme, never a native dialog/toast.
		for child in widgets.get_children():
			if child.name == "Feedback":
				child.queue_free()
		var feedback := text(caption, Vector2(100, 555), 18, title_color)
		feedback.name = "Feedback"


func reset_touch() -> void:
	stick_id = -1
	look_id = -1
	run_id = -1
	touch_points.clear()
	stick_delta = Vector2.ZERO
	if game != null and is_instance_valid(game.player):
		game.player.reset_controls()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag:
		return
	var p: Vector2 = (event.position - position) / unit
	if event is InputEventScreenTouch:
		if event.pressed:
			# Manually route touch to Controls: mouse emulation stays off for multitouch.
			for child in widgets.get_children():
				if (
					child is Button
					and child.visible
					and not child.disabled
					and Rect2(child.position, child.size).has_point(p)
				):
					child.pressed.emit()
					get_viewport().set_input_as_handled()
					return
			if page == "settings":
				for child in widgets.get_children():
					if child is HSlider and Rect2(child.position, child.size).grow(20).has_point(p):
						var v := clampf((p.x - child.position.x) / child.size.x, 0, 1)
						child.value = v
						game.save_setting("volume", v)
			if page == "game":
				if p.distance_to(Vector2(150, 575)) < 135 and stick_id < 0:
					stick_id = event.index
					touch_points[event.index] = p
					game.player.stick_heading = game.player.yaw
					game.player.stick_engaged = true
					set_stick(p)
				elif look_id < 0:
					look_id = event.index
					touch_points[event.index] = p
		else:
			touch_points.erase(event.index)
			if event.index == stick_id:
				stick_id = -1
				stick_delta = Vector2.ZERO
				game.player.stick = Vector2.ZERO
				game.player.stick_engaged = false
				queue_redraw()
			if event.index == look_id:
				look_id = -1
	elif page == "game":
		if event.index == stick_id:
			touch_points[event.index] = p
			set_stick(p)
		elif event.index == look_id:
			var previous: Vector2 = touch_points.get(event.index, p)
			touch_points[event.index] = p
			# Use absolute per-finger positions. Web multitouch can report a
			# shared or stale event.relative value, which makes the camera jump
			# when the movement thumb is held at the same time.
			game.player.look((p - previous) * 0.78)
	get_viewport().set_input_as_handled()


func set_stick(p: Vector2) -> void:
	stick_delta = (p - Vector2(150, 575)).limit_length(65)
	if not game.player.stick_engaged and stick_delta.length() > 7:
		game.player.stick_heading = game.player.yaw
		game.player.stick_engaged = true
	game.player.stick = stick_delta / 65 if stick_delta.length() > 7 else Vector2.ZERO
	if game.player.stick.length_squared() < 0.001:
		game.player.stick_engaged = false
	queue_redraw()


func _process(dt: float) -> void:
	if page == "game":
		message_time = maxf(0, message_time - dt)
		var ratio: float = game.player.health / game.player.max_health
		hearts.text = ""
		for segment in range(3):
			var fill := clampf(ratio * 3 - segment, 0, 1)
			var tint := Color("4e6668").lerp(Color("efa88b"), fill)
			hearts.text += "[color=#%s]♥ [/color]" % tint.to_html(false)
		camera_label.text = game.player.cameras.MODES[game.player.cameras.mode]
		shoulder_button.visible = game.player.cameras.mode == 2 or game.player.cameras.aiming
		action_buttons.aim.modulate = Color("edcf94") if game.player.cameras.aiming else Color.WHITE
		action_buttons.crouch.modulate = Color("edcf94") if game.player.crouching else Color.WHITE
		action_buttons.sprint.modulate = Color("edcf94") if game.player.sprinting else Color.WHITE
		queue_redraw()
		var ranged: bool = int(game.store.data.bag.weapon) != 0
		action_buttons.attack.text = "SHOOT" if ranged else "STRIKE"
		action_buttons.weapon.text = (
			(
				"PISTOL · %d" % game.store.data.bag.get("bullets", 0)
				if int(game.store.data.bag.weapon) == 2
				else "BOW · %d" % game.store.data.bag.arrows
			)
			if ranged
			else "SWORD"
		)
		health.value = game.player.health / game.player.max_health * 100
		stamina.value = game.player.stamina
		vitals.text = (
			("PEACEFUL CAMP • " if game.is_spawn_protected() else "")
			+ (
				"%s • %d HP   COINS %d   DIAMONDS %d"
				% [
					game.store.HEROES[int(game.store.data.hero)],
					int(game.player.health),
					game.store.data.coins,
					int(game.living.state().diamonds) if game.living != null else 0
				]
			)
		)
		var goal: PackedStringArray = game.objective().split(" / ", true, 1)
		quest_title.text = (
			"ISLAND %02d  /  %s" % [int(game.store.data.island) + 1, goal[0].strip_edges()]
		)
		objective.text = goal[1].strip_edges() if goal.size() > 1 else goal[0]
		prompt.text = game.interaction_prompt()
		prompt.visible = not prompt.text.is_empty()
		notice.text = message if message_time > 0 else ""


func _draw() -> void:
	if page == "game":
		draw_style_panel(Rect2(28, 22, 566, 114), Color(0.035, 0.09, 0.11, 0.82))
		draw_style_panel(Rect2(456, 628, 364, 70), Color(0.035, 0.09, 0.11, 0.78))
		if message_time > 0:
			draw_style_panel(Rect2(326, 475, 576, 52), Color(0.035, 0.09, 0.11, 0.78))
		if game.player.cameras.aiming or game.player.cameras.mode == 1:
			draw_arc(Vector2(640, 360), 6, 0, TAU, 20, Color("f5e7c8"), 1, true)
			draw_line(Vector2(630, 360), Vector2(635, 360), Color("f5e7c8"), 1, true)
			draw_line(Vector2(645, 360), Vector2(650, 360), Color("f5e7c8"), 1, true)
		draw_circle(Vector2(150, 575), 86, Color(0.035, 0.09, 0.11, 0.30))
		draw_arc(Vector2(150, 575), 86, 0, TAU, 64, Color(0.79, 0.88, 0.77, 0.5), 2, true)
		draw_circle(Vector2(150, 575) + stick_delta, 34, Color(0.83, 0.85, 0.72, 0.55))
	else:
		draw_rect(
			Rect2(-1000, -1000, 3300, 2700),
			Color(0.035, 0.10, 0.14, 0.18 if page == "lobby" else 0.58)
		)
		if page == "lobby":
			draw_rect(Rect2(-1000, -1000, 3300, 2700), Color("191b35"))
			draw_circle(Vector2(1120, 60), 320, Color("272446"))
			draw_circle(Vector2(485, 680), 250, Color("1e3545"))
			draw_style_panel(Rect2(35, 30, 375, 660), Color("252840"))
			if level_points.size() > 1:
				var curve := Curve2D.new()
				for i in range(level_points.size()):
					curve.add_point(
						level_points[i],
						Vector2(-36, 0) if i < 4 else Vector2(36, 0),
						Vector2(36, 0) if i < 4 else Vector2(-36, 0)
					)
				draw_polyline(curve.get_baked_points(), Color("565273"), 14, true)
				draw_polyline(curve.get_baked_points(), Color("aaa0c1"), 3, true)
		else:
			draw_style_panel(Rect2(60, 40, 1160, 640), Color(0.12, 0.12, 0.22, 0.94))


func draw_style_panel(rect: Rect2, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.border_color = Color(0.75, 0.85, 0.72, 0.24)
	style.set_border_width_all(1)
	draw_style_box(style, rect)


func show_brief() -> void:
	game.track_expedition = true
	game.playing = false
	game.player.reset_controls()
	page = "brief"
	clear()
	header("EXPEDITION BRIEF", "Your route, your objective, your reward. Gameplay is paused.")
	for child in widgets.get_children():
		if child is Button and child.text == "← BACK":
			child.pressed.disconnect(show_lobby)
			child.pressed.connect(game.resume_game)
	if not game.use_expeditions:
		text(game.objective(), Vector2(100, 225), 22)
		return
	text(game.expedition.TITLES[game.expedition.kind], Vector2(100, 203), 26, title_color)
	var description := text(game.expedition.BRIEFS[game.expedition.kind], Vector2(100, 252), 18)
	description.size = Vector2(1000, 70)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in range(3):
		var done: bool = i in game.expedition.completed()
		var index := i
		var row := button(
			("✓  " if done else str(i + 1) + "  ") + game.expedition.stages[i].title,
			Rect2(100, 340 + i * 62, 500, 52),
			func():
				game.expedition.focus = index
				game.expedition.route_clock = 0
				game.resume_game()
		)
		row.disabled = (
			done
			or (
				game.expedition.kind == 1
				and i == 2
				and (0 not in game.expedition.completed() or 1 not in game.expedition.completed())
			)
		)
	text(
		"EXTRACTION PAYMENT  +%d STARLIGHT" % game.expedition.reward(),
		Vector2(730, 360),
		19,
		title_color
	)
	text("LANDSCAPE  " + game.terrain.landform.to_upper(), Vector2(730, 414), 17)
	var help := text(
		"Cyan trail: next objective\nColored shafts: unclaimed contracts / resources\nINTERACT: calibrate / open\nSHOOT / STRIKE: defeat marked guards",
		Vector2(730, 454),
		17
	)
	help.size = Vector2(430, 120)
	button("FOLLOW THE SIGNAL  →", Rect2(730, 600, 430, 52), game.resume_game)
