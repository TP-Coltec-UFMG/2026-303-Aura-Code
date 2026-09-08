@tool
extends StaticBody2D
## A forma editável em CollisionPolygon2D também determina o desenho.
func _ready() -> void:
	add_to_group("paredes")
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	for filho in get_children():
		if not filho is CollisionPolygon2D:
			continue
		var pontos: PackedVector2Array = filho.polygon
		if pontos.size() < 3:
			continue
		draw_colored_polygon(pontos, Color("344858"))
		# Painéis bem simples nas partes largas: quatro cantos precisam estar na parede.
		for y in range(8, 270, 36):
			for x in range(8, 480, 36):
				var ret := Rect2(x, y, 24, 24)
				var cabe := true
				for canto in [ret.position, ret.end, Vector2(ret.end.x, ret.position.y), Vector2(ret.position.x, ret.end.y)]:
					if not Geometry2D.is_point_in_polygon(canto, pontos): cabe = false
				if not cabe: continue
				draw_rect(ret, Color("2b3e4e"))
				draw_rect(ret, Color("476071"), false, 1)
				for linha in range(3):
					draw_line(Vector2(x + 5, y + 6 + linha * 4), Vector2(x + 18, y + 6 + linha * 4), Color("172936"), 2)
				draw_rect(Rect2(x + 5, y + 19, 3, 1), Color("91ab9f"))
		for n in range(pontos.size()):
			var a := pontos[n]
			var b := pontos[(n + 1) % pontos.size()]
			draw_line(a, b, Color("81908b") if b.x > a.x else Color("111d2a"), 2.0)
			if a.distance_to(b) > 28:
				var meio := (a + b) * 0.5
				draw_rect(Rect2(meio - Vector2.ONE, Vector2(2, 2)), Color("a6ac92"))
