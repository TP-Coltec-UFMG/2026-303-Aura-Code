extends Line2D

@export_range(0.1, 2.0, 0.1) var tempo_piscar: float = 0.5

const DURACAO_INDICADOR: float = 10.0

@export var ciclo_final: bool = false

var _quest: Node
var _temporizador: Timer
var _tempo_restante: float = DURACAO_INDICADOR

var _tween: Tween
var _alpha_original: float = 1.0
var _luzes: Array[PointLight2D] = []
var _energias_originais: Array[float] = []
var _visibilidades_originais: Array[bool] = []

@onready var point_light_2d: PointLight2D = $"../PointLight2D"
@onready var point_light_2d_2: PointLight2D = $"../PointLight2D2"
@onready var point_light_2d_3: PointLight2D = $"../PointLight2D3"
@onready var point_light_2d_4: PointLight2D = $"../PointLight2D4"


func _enter_tree() -> void:
	# Também reconecta se o mesmo nó sair e voltar à árvore sem outro _ready.
	call_deferred("_conectar_quest")


func _ready() -> void:
	if ciclo_final:
		_tempo_restante = float(SaveGame.office_mission_state().get("indicator_remaining", 10.0))
	_temporizador = Timer.new()
	_temporizador.one_shot = true
	_temporizador.process_mode = Node.PROCESS_MODE_PAUSABLE
	_temporizador.timeout.connect(_liberar_indicador)
	add_child(_temporizador)
	_alpha_original = self_modulate.a
	_luzes = [point_light_2d, point_light_2d_2, point_light_2d_3, point_light_2d_4]
	for luz in _luzes:
		_energias_originais.append(luz.energy)
		_visibilidades_originais.append(luz.visible)
	_definir_visibilidade(false)


func _conectar_quest() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_quest = get_tree().current_scene.get_node_or_null("QuestController")
	if _quest == null:
		push_warning("Borda do elevador sem QuestController na cena.")
		return
	if not _quest.orientacao_elevador_iniciada.is_connected(_sincronizar):
		_quest.orientacao_elevador_iniciada.connect(_sincronizar)
	_sincronizar()


func _exit_tree() -> void:
	_suspender_contagem()
	if is_instance_valid(_quest) and _quest.orientacao_elevador_iniciada.is_connected(_sincronizar):
		_quest.orientacao_elevador_iniciada.disconnect(_sincronizar)
	_quest = null
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_definir_visibilidade(false)
	_restaurar_intensidades()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_definir_visibilidade(false)
	elif what == NOTIFICATION_UNPAUSED and is_node_ready() and is_inside_tree() and not is_queued_for_deletion():
		call_deferred("_sincronizar")


func _sincronizar() -> void:
	# Resetar retoma o jogo e remove a cena antes deste callback adiado.
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if not is_instance_valid(_quest) or not _quest.is_inside_tree() or _quest.is_queued_for_deletion():
		return
	if get_tree().paused:
		_definir_visibilidade(false)
		return
	if not _quest.orientar_elevador:
		_suspender_contagem()
		_definir_visibilidade(false)
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = null
		_restaurar_intensidades()
		return
	_definir_visibilidade(true)
	# Só inicia ou retoma: sinais repetidos nunca reiniciam os dez segundos.
	if _temporizador.is_stopped():
		_temporizador.start(_tempo_restante)
	if _tween != null and _tween.is_valid():
		return
	# Um único Tween: borda e energias percorrem as mesmas duas fases.
	_tween = create_tween().set_loops()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	_animar_fase(0.2)
	_animar_fase(1.0)


func _suspender_contagem() -> void:
	if is_instance_valid(_temporizador) and not _temporizador.is_stopped():
		_tempo_restante = _temporizador.time_left
		_temporizador.stop()


func _liberar_indicador() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if ciclo_final:
		SaveGame.office_mission_state()["indicator_remaining"] = 0.0
	_temporizador.stop()
	_definir_visibilidade(false)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	for luz in _luzes:
		if is_instance_valid(luz):
			luz.queue_free()
	if ciclo_final:
		get_parent().queue_free()
	else:
		queue_free()


func _animar_fase(fator: float) -> void:
	_tween.tween_property(self, "self_modulate:a", _alpha_original * fator, tempo_piscar)
	for i in range(_luzes.size()):
		if is_instance_valid(_luzes[i]):
			_tween.parallel().tween_property(_luzes[i], "energy", _energias_originais[i] * fator, tempo_piscar)


func _definir_visibilidade(ativa: bool) -> void:
	visible = ativa
	# As luzes são irmãs da borda; hide() no Line2D não as oculta.
	for i in range(_luzes.size()):
		if is_instance_valid(_luzes[i]):
			_luzes[i].visible = ativa and _visibilidades_originais[i]


func _restaurar_intensidades() -> void:
	self_modulate.a = _alpha_original
	for i in range(_luzes.size()):
		if is_instance_valid(_luzes[i]):
			_luzes[i].energy = _energias_originais[i]


func _process(_delta: float) -> void:
	if ciclo_final and is_instance_valid(_temporizador) and not _temporizador.is_stopped():
		SaveGame.office_mission_state()["indicator_remaining"] = _temporizador.time_left
