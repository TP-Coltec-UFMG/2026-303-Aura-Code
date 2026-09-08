@tool
extends Node2D

func _draw() -> void:
	draw_rect(Rect2(-4, -4, 488, 278), Color("425868"))
	draw_rect(Rect2(-2, -2, 484, 274), Color("101923"))
	draw_rect(Rect2(0, 0, 480, 270), Color("1b2a36"))
	for y in range(0, 270, 30):
		for x in range(0, 480, 30):
			@warning_ignore("integer_division")
			var cor := Color("1d2d39") if (x / 30 + y / 30) % 2 == 0 else Color("1b2a36")
			draw_rect(Rect2(x, y, 29, 29), cor)
			@warning_ignore("integer_division")
			if (x / 30 + y / 30) % 4 == 0:
				draw_rect(Rect2(x + 3, y + 3, 1, 1), Color("354652"))
