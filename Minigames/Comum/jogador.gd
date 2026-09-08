extends CharacterBody2D
signal capturado
signal iniciou_movimento
signal parou
signal saiu_da_arena
@export var deslizar: bool = false
@export var velocidade: float = 118.0
@export var raio: float = 8.0
var habilitado: bool = true
var movendo: bool = false
var direcao := Vector2.ZERO
var historico: Array[Vector2] = []
var movimentos: int = 0
var tempo: float = 0.0
var falhou: bool = false
var alvo: Vector2

func _ready() -> void:
	add_to_group("jogador")
	collision_layer = 2
	collision_mask = 1
	var forma := CollisionShape2D.new()
	if deslizar:
		var ret := RectangleShape2D.new()
		ret.size = Vector2.ONE * raio * 2.0
		forma.shape = ret
	else:
		var circulo := CircleShape2D.new()
		circulo.radius = raio
		forma.shape = circulo
	add_child(forma)

func ler_direcao() -> Vector2:
	var d := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	d += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	return d.limit_length()

func _physics_process(delta: float) -> void:
	tempo += delta
	queue_redraw()
	if not habilitado:
		return
	if not deslizar:
		velocity = ler_direcao() * velocidade
		move_and_slide()
		return
	if not movendo:
		var entrada := ler_direcao()
		if entrada != Vector2.ZERO:
			direcao = Vector2(signf(entrada.x), 0) if absf(entrada.x) > absf(entrada.y) else Vector2(0, signf(entrada.y))
	else:
		# Pixels por segundo: velocidade independe do FPS de renderização.
		var colisao := move_and_collide(direcao * velocidade * delta)
		if colisao:
			movendo = false
			direcao = Vector2.ZERO
			parou.emit()
		if position.x < -raio or position.x > 480 + raio or position.y < -raio or position.y > 270 + raio:
			habilitado = false
			saiu_da_arena.emit()

func _unhandled_key_input(evento: InputEvent) -> void:
	if not habilitado or not deslizar or not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	if evento.physical_keycode == KEY_SPACE:
		iniciar(direcao)
	elif evento.physical_keycode == KEY_Z:
		desfazer()

func iniciar(d: Vector2) -> void:
	if movendo or not habilitado or d == Vector2.ZERO:
		return
	historico.append(position)
	direcao = d
	movendo = true
	movimentos += 1
	iniciou_movimento.emit()

func desfazer() -> void:
	if historico.is_empty():
		return
	position = historico.pop_back()
	movendo = false
	habilitado = true
	direcao = Vector2.ZERO
	velocity = Vector2.ZERO
	movimentos = maxi(0, movimentos - 1)
	parou.emit()

func detectar() -> void:
	if falhou or not habilitado:
		return
	falhou = true
	habilitado = false
	capturado.emit()

func _draw() -> void:
	var tamanho := 48.0 * raio / 18.0 if deslizar else 30.0
	draw_rect(Rect2(Vector2(-raio, raio - 3), Vector2(raio * 2, 4)), Color(0.02, 0.04, 0.06, 0.4))
	var frame := int(tempo * 5) % 4
	draw_texture_rect(VisualAsimov.quadro(0, frame), Rect2(Vector2.ONE * -tamanho / 2.0, Vector2.ONE * tamanho), false, VisualAsimov.VERMELHO if falhou else Color.WHITE)
	if deslizar and not movendo and direcao != Vector2.ZERO and habilitado:
		var ponta := direcao * (raio + 12)
		var lado := direcao.orthogonal() * 4
		draw_line(direcao * (raio + 3), ponta, VisualAsimov.CIANO, 2)
		draw_polyline(PackedVector2Array([ponta - direcao * 5 + lado, ponta, ponta - direcao * 5 - lado]), VisualAsimov.CIANO, 2)
