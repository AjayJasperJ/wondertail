extends Control
## Resolution-independent item artwork, shared by pack and crafting controls.
var item := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, size / 64.0)
	match item:
		"wood":
			draw_style_box(log_style(), Rect2(9, 22, 44, 24))
			draw_circle(Vector2(15, 34), 11, Color("d8a56a"))
			draw_arc(Vector2(15, 34), 6, 0, TAU, 24, Color("82532f"), 2, true)
			draw_line(Vector2(30, 27), Vector2(48, 27), Color("cb9555"), 2, true)
		"crystal":
			draw_colored_polygon(
				PackedVector2Array(
					[
						Vector2(32, 5),
						Vector2(50, 24),
						Vector2(43, 48),
						Vector2(26, 58),
						Vector2(12, 36),
						Vector2(18, 15)
					]
				),
				Color("49dce8")
			)
			draw_colored_polygon(
				PackedVector2Array([Vector2(32, 5), Vector2(32, 45), Vector2(18, 15)]),
				Color("b2fbff")
			)
			draw_line(Vector2(32, 5), Vector2(43, 48), Color("20a9d1"), 3, true)
		"herbs":
			draw_line(Vector2(32, 55), Vector2(32, 14), Color("abdf80"), 4, true)
			for side in [-1, 1]:
				for y in [25, 42]:
					draw_colored_polygon(
						PackedVector2Array(
							[
								Vector2(32, y),
								Vector2(32 + side * 22, y - 13),
								Vector2(32 + side * 18, y + 3)
							]
						),
						Color("70d697")
					)
		"tonic":
			draw_style_box(glass_style(), Rect2(17, 20, 30, 36))
			draw_style_box(log_style(), Rect2(23, 9, 18, 12))
			draw_line(Vector2(25, 42), Vector2(39, 42), Color.WHITE, 4, true)
			draw_line(Vector2(32, 35), Vector2(32, 49), Color.WHITE, 4, true)
		"arrows":
			for x in [20, 33, 46]:
				draw_line(Vector2(x - 9, 55), Vector2(x + 3, 15), Color("e3bc77"), 3, true)
				draw_colored_polygon(
					PackedVector2Array(
						[Vector2(x + 5, 7), Vector2(x - 3, 19), Vector2(x + 10, 22)]
					),
					Color("e3f0f5")
				)
		"bullets":
			for x in [15, 32, 49]:
				draw_style_box(log_style(), Rect2(x - 5, 26, 11, 27))
				draw_colored_polygon(
					PackedVector2Array([Vector2(x - 5, 26), Vector2(x, 12), Vector2(x + 6, 26)]),
					Color("ffdd8b")
				)
		"sword":
			draw_line(Vector2(16, 54), Vector2(47, 10), Color("c7e6ef"), 8, true)
			draw_line(Vector2(10, 39), Vector2(30, 53), Color("f5c477"), 5, true)
			draw_line(Vector2(12, 59), Vector2(21, 46), Color("936548"), 6, true)
		"bow":
			draw_arc(Vector2(11, 32), 28, -1.2, 1.2, 28, Color("e7ad67"), 5, true)
			draw_line(Vector2(21, 6), Vector2(21, 58), Color("e4e9d4"), 2, true)
			draw_line(Vector2(10, 32), Vector2(55, 32), Color("a9def2"), 3, true)
		"gun":
			draw_colored_polygon(
				PackedVector2Array(
					[
						Vector2(10, 17),
						Vector2(55, 17),
						Vector2(55, 29),
						Vector2(33, 30),
						Vector2(25, 52),
						Vector2(11, 48),
						Vector2(18, 28),
						Vector2(10, 28)
					]
				),
				Color("91adca")
			)
			draw_line(Vector2(14, 19), Vector2(52, 19), Color("e1edf3"), 3, true)


func log_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("9d693d")
	style.set_corner_radius_all(5)
	return style


func glass_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("b683ee")
	style.border_color = Color("e0c7ff")
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	return style
