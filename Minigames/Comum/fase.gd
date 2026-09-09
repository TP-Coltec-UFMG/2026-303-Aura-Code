extends Node2D

const GAME_TIMER_SCENE := preload("res://Objects/controle_de_tempo.tscn")

@export_enum("Vigilância", "Deslizar") var jogo: int = 0
@export_range(0, 3) var fase: int = 0
@export var nome_fase: String = "Primeiro acesso"
@export_multiline var dica: String = "Alcance o terminal sem entrar no cone vermelho."
var estado: String = "jogando"
var tempo: float = 0.0
var hud: Control
var modal: Control
var contador: Label
var sons: SonsAsimov
var game_timer: Control
@onready var jogador = $Arena/Jogador
@onready var objetivo = $Arena/Objetivo
signal venceu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	sons = SonsAsimov.new()
	add_child(sons)
	var camada := CanvasLayer.new()
	add_child(camada)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = VisualAsimov.tema()
	camada.add_child(hud)
	VisualAsimov.painel(hud, Rect2(0, 0, 480, 31), VisualAsimov.FUNDO)
	VisualAsimov.texto(hud, "VIGILÂNCIA" if jogo == 0 else "DESLIZAR", Rect2(14, 7, 135, 18), 15)
	VisualAsimov.texto(hud, nome_fase, Rect2(143, 10, 195, 15), 9, VisualAsimov.SUAVE)
	VisualAsimov.texto(hud, "FASE", Rect2(11, 44, 45, 14), 9, VisualAsimov.SUAVE)
	VisualAsimov.texto(hud, "%02d" % (fase + 1), Rect2(11, 57, 41, 23), 22, VisualAsimov.CIANO)
	VisualAsimov.texto(hud, "/ 04", Rect2(16, 81, 34, 14), 9, VisualAsimov.SUAVE)
	VisualAsimov.texto(hud, "ALVO", Rect2(434, 47, 44, 14), 9, VisualAsimov.VERDE)
	VisualAsimov.icone(hud, 2 if jogo == 0 else 3, 0, Rect2(431, 62, 33, 33))
	contador = VisualAsimov.texto(hud, "", Rect2(12, 128, 47, 41), 9, VisualAsimov.SUAVE)
	VisualAsimov.texto(hud, "[R]:\n REFAZER\n\n[ESC]:\n PAUSA", Rect2(432, 146, 47, 79), 8, VisualAsimov.SUAVE)
	_adicionar_cronometro(camada)
	var instrucao := "WASD / SETAS: mover    |    Evite os cones vermelhos."
	if jogo == 1:
		instrucao = "WASD / SETAS: direção    ESPAÇO: deslizar    Z: desfazer"
	VisualAsimov.texto(hud, instrucao, Rect2(15, 253, 450, 15), 9)
	jogador.capturado.connect(func(): falhar("SINAL DETECTADO", "Espere o sensor virar ou use uma cobertura."))
	jogador.saiu_da_arena.connect(func(): falhar("FORA DO SISTEMA", "Desfaça o movimento ou tente outra rota."))
	jogador.iniciou_movimento.connect(func(): sons.tocar("passo"))
	jogador.parou.connect(func(): sons.tocar("toque"))
	objetivo.alcancado.connect(vencer)


func _adicionar_cronometro(camada: CanvasLayer) -> void:
	game_timer = GAME_TIMER_SCENE.instantiate() as Control
	game_timer.name = "GameTimer"
	game_timer.process_mode = Node.PROCESS_MODE_PAUSABLE
	camada.add_child(game_timer)
	var icon := game_timer.get_node_or_null("Control") as Control
	if icon != null:
		icon.hide()
	var timer_label := game_timer.get_node_or_null("Label") as Label
	if timer_label != null:
		timer_label.anchor_left = 0.0
		timer_label.anchor_right = 0.0
		timer_label.offset_left = 345.0
		timer_label.offset_right = 425.0
		timer_label.offset_top = 7.0
		timer_label.offset_bottom = 24.0


func _unhandled_key_input(evento: InputEvent) -> void:
	if not evento is InputEventKey or not evento.pressed or evento.echo:
		return
	if evento.physical_keycode == KEY_ESCAPE:
		if estado == "pausado": retomar()
		elif estado == "jogando": pausar()
	elif evento.physical_keycode == KEY_R:
		reiniciar()
	elif evento.physical_keycode == KEY_Z and estado == "falhou" and jogo == 1:
		desfazer_falha()

func limpar_modal() -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null

func abrir_modal(titulo: String, mensagem: String, cor: Color) -> Control:
	limpar_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(modal)
	var escuro := ColorRect.new()
	escuro.color = Color(0.025, 0.04, 0.055, 0.84)
	escuro.size = Vector2(480, 270)
	modal.add_child(escuro)
	VisualAsimov.painel(modal, Rect2(95, 55, 291, 166), VisualAsimov.PAINEL, cor)
	VisualAsimov.texto(modal, titulo, Rect2(110, 65, 261, 21), 18, cor)
	var texto := VisualAsimov.texto(modal, mensagem, Rect2(110, 92, 261, 57), 12)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return modal

func pausar() -> void:
	if estado != "jogando": return
	estado = "pausado"
	get_tree().paused = true
	abrir_modal("SISTEMA EM PAUSA", "", VisualAsimov.CIANO)
	VisualAsimov.botao(modal, "CONTINUAR", Rect2(110, 154, 123, 22), retomar).grab_focus()
	VisualAsimov.botao(modal, "REINICIAR", Rect2(248, 154, 123, 22), reiniciar)
	VisualAsimov.botao(modal, "SAIR DO HACKER", Rect2(110, 186, 261, 21), Progresso.menu)

func retomar() -> void:
	limpar_modal()
	estado = "jogando"
	get_tree().paused = false

func reiniciar() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func falhar(titulo: String, mensagem: String) -> void:
	if estado != "jogando": return
	estado = "falhou"
	sons.tocar("erro")
	$Arena.process_mode = Node.PROCESS_MODE_DISABLED
	abrir_modal(titulo, mensagem, VisualAsimov.VERMELHO)
	VisualAsimov.botao(modal, "TENTAR DE NOVO", Rect2(110, 154, 261, 22), reiniciar).grab_focus()
	if jogo == 1:
		VisualAsimov.botao(modal, "DESFAZER [Z]", Rect2(110, 185, 123, 21), desfazer_falha)
	VisualAsimov.botao(modal, "SAIR DO HACKER", Rect2(248 if jogo == 1 else 110, 185, 123 if jogo == 1 else 261, 21), Progresso.menu)

func desfazer_falha() -> void:
	if jogador.historico.is_empty(): return
	jogador.desfazer()
	$Arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	limpar_modal()
	estado = "jogando"

func vencer() -> void:
	if estado != "jogando": return
	estado = "venceu"
	if is_instance_valid(game_timer) and game_timer.has_method("pausar_timer"):
		game_timer.call("pausar_timer")
	jogador.habilitado = false
	for sensor in get_tree().get_nodes_in_group("sensores"):
		sensor.set_physics_process(false)
	Progresso.concluir(jogo, fase)
	sons.tocar("ok")
	await get_tree().create_timer(0.45).timeout
	if fase == 3:
		abrir_modal("ACESSO LIBERADO", "Acesso a sala do chefe concedido", VisualAsimov.VERDE)
		
		
	if fase < 3:
		Progresso.abrir(jogo, fase + 1)
	else:
		VisualAsimov.botao(modal, Progresso.texto_saida(), Rect2(110, 154, 261, 22), Progresso.menu).grab_focus()
