extends Area2D
signal alcancado
@export var engrenagem: bool = false
@export var tamanho: float = 1.0
var concluido: bool = false
var tempo: float = 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var col := CollisionShape2D.new()
	var forma := RectangleShape2D.new()
	forma.size = Vector2(16, 16) * tamanho
	col.shape = forma
	add_child(col)
	body_entered.connect(_entrou)

func _entrou(corpo: Node2D) -> void:
	if concluido or not corpo.is_in_group("jogador") or not corpo.habilitado:
		return
	concluido = true
	corpo.habilitado = false
	alcancado.emit()

func _process(delta: float) -> void:
	tempo += delta
	queue_redraw()

func _draw() -> void:
	var largura := (48.0 if engrenagem else 36.0) * tamanho
	var cor := VisualAsimov.VERDE
	cor.a = 0.5 + sin(tempo * 4) * 0.15
	var ret := Rect2(Vector2.ONE * -largura * 0.5, Vector2.ONE * largura)
	draw_rect(ret.grow(-3), cor, false, 1)
	var linha := 3 if engrenagem else 2
	var frame := int(tempo * 5) % 4 if engrenagem else (2 + int(tempo * 3) % 2 if concluido else int(tempo * 3) % 2)
	draw_texture_rect(VisualAsimov.quadro(linha, frame), ret, false)
	if concluido:
		draw_line(Vector2(-5, 0), Vector2(-1, 4), VisualAsimov.VERDE, 2)
		draw_line(Vector2(-1, 4), Vector2(7, -5), VisualAsimov.VERDE, 2)
