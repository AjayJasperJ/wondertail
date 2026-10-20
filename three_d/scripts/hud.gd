extends Control
var game
var page := "lobby"
var widgets := Control.new()
var objective: Label
var vitals: Label
var notice: Label
var health: ProgressBar
var stamina: ProgressBar
var prompt: Button
var action_buttons: Dictionary = {}
var stick_id := -1
var look_id := -1
var run_id := -1
var stick_delta := Vector2.ZERO
var message := ""
var message_time := 0.0
var unit := 1.0
var title_color := Color("ffe5ab")


func setup(owner_game) -> void:
	game = owner_game
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(widgets)
	widgets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 20
	for type in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("244954") if type != "pressed" else Color("537c77")
		style.border_color = Color("79938b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(15)
		style.content_margin_left = 16
		style.content_margin_right = 16
		theme.set_stylebox(type, "Button", style)
	theme.set_color("font_color", "Button", Color("fff1d5"))
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
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	widgets.add_child(label)
	return label


func button(caption: String, rect: Rect2, callback: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.position = rect.position
	b.size = rect.size
	b.pressed.connect(callback)
	widgets.add_child(b)
	return b


func show_lobby() -> void:
	page = "lobby"
	clear()
	text("A WORLD WORTH WANDERING", Vector2(72, 78), 17, Color("a7d6cb"))
	text("WONDERTAIL", Vector2(66, 104), 62, title_color)
	text("THE SKYBOUND EXPEDITION", Vector2(73, 179), 19, Color("b5d6d2"))
	text("Beyond the path, something is waiting.", Vector2(74, 237), 22)
	text(
		"Climb the highlands. Wake an ancient beacon.\nBring a little kindness to the unknown.",
		Vector2(74, 278),
		19
	)
	button("CONTINUE EXPEDITION  →", Rect2(74, 377, 367, 60), game.start_game)
	button("EXPLORERS", Rect2(74, 453, 174, 51), func(): show_heroes())
	button("ISLAND ATLAS", Rect2(262, 453, 179, 51), func(): show_atlas())
	button("SETTINGS", Rect2(74, 521, 174, 51), func(): show_settings())
	text("3D EDITION  /  0.9.0", Vector2(76, 655), 15, Color("a7c3bf"))
	text("OFFLINE • NO ADS • YOUR OWN PACE", Vector2(800, 660), 15, Color("d6e9db"))
	text("YOUR NEXT CHAPTER", Vector2(861, 115), 16, Color("a7d6cb"))
	text("ISLAND %02d" % (int(game.store.data.island) + 1), Vector2(860, 145), 39, title_color)
	text(game.island_name(), Vector2(861, 204), 21)
	text(
		(
			"%s  /  %d Starlight"
			% [game.store.HEROES[int(game.store.data.hero)], game.store.data.coins]
		),
		Vector2(861, 245),
		18
	)


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
	page = "atlas"
	clear()
	var unlocked := int(game.store.data.unlocked)
	if offset < 0:
		offset = maxi(0, int(game.store.data.island) - 2)
	header("THE ISLAND ATLAS", "Revisit restored places, or continue toward your newest frontier.")
	for i in range(offset, mini(offset + 6, unlocked + 1)):
		var memory: Dictionary = game.store.memory(i)
		var label := (
			"%02d   %s   %s"
			% [i + 1, game.island_name(i), "✦ restored" if memory.restored else "unexplored"]
		)
		button(label, Rect2(100, 196 + (i - offset) * 60, 1060, 49), func(): game.select_island(i))
	if offset > 0:
		button("← EARLIER", Rect2(740, 600, 190, 52), func(): show_atlas(maxi(0, offset - 6)))
	if offset + 6 <= unlocked:
		button("LATER →", Rect2(950, 600, 190, 52), func(): show_atlas(offset + 6))


func show_settings() -> void:
	page = "settings"
	clear()
	header(
		"TRAVEL LIGHT",
		"Settings apply immediately. Low detail disables shadows and distant scenery."
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
		"LOW" if int(game.store.data.quality) == 0 else "STANDARD",
		Rect2(450, 315, 300, 54),
		func():
			game.save_setting("quality", 1 - int(game.store.data.quality))
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
	objective = text("", Vector2(36, 27), 24, title_color)
	text("W O N D E R T A I L", Vector2(36, 63), 14, Color("bed6d0"))
	button("Ⅱ  CAMP", Rect2(1100, 26, 140, 48), game.pause_game)
	vitals = text("", Vector2(465, 608), 16)
	health = bar(Vector2(465, 638), Color("e89e80"))
	stamina = bar(Vector2(465, 655), Color("91d6c4"))
	notice = text("", Vector2(302, 682), 16, Color("fff1c7"))
	prompt = button("", Rect2(465, 540, 330, 51), game.interact)
	var entries := [
		["JUMP", Vector2(1120, 555), "jump"],
		["STRIKE", Vector2(1010, 615), "attack"],
		["DASH", Vector2(1120, 435), "dash"],
		["RUN", Vector2(900, 615), "sprint"]
	]
	for entry in entries:
		var action: String = entry[2]
		var b := button(entry[0], Rect2(entry[1], Vector2(94, 70)), func(): game.action(action))
		action_buttons[action] = b
		if action == "sprint":
			b.toggle_mode = true
	text("DRAG THE SKY TO LOOK", Vector2(920, 384), 14, Color("bfd6ce"))


func show_pause() -> void:
	page = "pause"
	clear()
	header(
		"TAKE A BREATH",
		"The world waits while this menu is open. Your discoveries are already saved."
	)
	button("RETURN TO THE TRAIL", Rect2(100, 220, 440, 62), game.resume_game)
	button("REST & CRAFT TONIC  •  5 STARLIGHT", Rect2(100, 305, 550, 62), game.craft_tonic)
	button("RETURN TO LOBBY", Rect2(100, 390, 440, 62), game.return_lobby)
	text(
		"WASD / arrows  move     Space  double jump     Shift  run\nF  strike     Q  dash     E  interact     Esc  pause\nDrag mouse / right thumb over the world to orbit camera.",
		Vector2(700, 250),
		19
	)
	# The header back button is also safe: it resumes to lobby through the controller.
	for child in widgets.get_children():
		if child is Button and child.text == "← BACK":
			child.pressed.disconnect(show_lobby)
			child.pressed.connect(game.return_lobby)


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
					set_stick(p)
				elif look_id < 0:
					look_id = event.index
		else:
			if event.index == stick_id:
				stick_id = -1
				stick_delta = Vector2.ZERO
				game.player.stick = Vector2.ZERO
				queue_redraw()
			if event.index == look_id:
				look_id = -1
	elif page == "game":
		if event.index == stick_id:
			set_stick(p)
		elif event.index == look_id:
			game.player.look(event.relative / unit)
	get_viewport().set_input_as_handled()


func set_stick(p: Vector2) -> void:
	stick_delta = (p - Vector2(150, 575)).limit_length(65)
	game.player.stick = stick_delta / 65 if stick_delta.length() > 7 else Vector2.ZERO
	queue_redraw()


func _process(dt: float) -> void:
	if page == "game":
		message_time = maxf(0, message_time - dt)
		health.value = game.player.health / game.player.max_health * 100
		stamina.value = game.player.stamina
		vitals.text = (
			"%s  •  %d HP     ✦ %d     SKYSEEDS %d/3"
			% [
				game.store.HEROES[int(game.store.data.hero)],
				int(game.player.health),
				game.store.data.coins,
				game.store.memory().seeds.size()
			]
		)
		objective.text = game.objective()
		prompt.text = game.interaction_prompt()
		prompt.visible = not prompt.text.is_empty()
		notice.text = message if message_time > 0 else ""


func _draw() -> void:
	if page == "game":
		draw_style_panel(Rect2(22, 16, 1000, 76), Color(0.05, 0.12, 0.16, 0.82))
		draw_style_panel(Rect2(450, 596, 360, 80), Color(0.05, 0.12, 0.16, 0.85))
		draw_style_panel(Rect2(290, 680, 700, 32), Color(0.05, 0.12, 0.16, 0.78))
		draw_circle(Vector2(150, 575), 86, Color(0.04, 0.13, 0.17, 0.48))
		draw_arc(Vector2(150, 575), 86, 0, TAU, 64, Color(0.79, 0.88, 0.77, 0.5), 2, true)
		draw_circle(Vector2(150, 575) + stick_delta, 34, Color(0.88, 0.87, 0.68, 0.7))
	else:
		draw_rect(Rect2(-1000, -1000, 3300, 2700), Color(0.035, 0.10, 0.14, 0.6))
		if page == "lobby":
			draw_style_panel(Rect2(830, 86, 390, 220), Color(0.05, 0.14, 0.18, 0.76))
		else:
			draw_style_panel(Rect2(60, 40, 1160, 640), Color(0.04, 0.12, 0.16, 0.87))


func draw_style_panel(rect: Rect2, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(20)
	style.border_color = Color(0.75, 0.85, 0.72, 0.24)
	style.set_border_width_all(1)
	draw_style_box(style, rect)
