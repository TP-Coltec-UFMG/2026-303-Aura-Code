extends Sprite2D

@onready var label: Label = $Label

@export var caracteres_por_segundo: float = 8.0
@export var tempo_minimo: float = 3.0
@export var tempo_maximo: float = 10.0
@export var tempo_fade_out: float = 0.5

signal pensamento_concluido
signal pensamento_finalizado(id: String)
signal pensamento_iniciado(id: String)

var _concluidos: Dictionary = {}
var _descartados: Dictionary = {}
var _fila: Array[Dictionary] = []
var _ativo: Dictionary = {}
var _fase: String = ""
var _duracao: float = 0.0
var _tween: Tween
var _geracao: int = 0


func _ready() -> void:
	hide()


# IDs estáveis distinguem o evento do texto e impedem duplicação após carregar.
func enfileirar(id: String, texto: String) -> void:
	if id.is_empty() or tem_pensamento(id):
		return
	_fila.append({"id": id, "texto": texto})
	_iniciar_proximo()


func atualizar_texto(id: String, texto: String) -> void:
	if str(_ativo.get("id", "")) == id:
		_ativo["texto"] = texto
		label.text = texto
	for item in _fila:
		if item["id"] == id:
			item["texto"] = texto


func tem_pensamento(id: String) -> bool:
	if foi_concluido(id) or _descartados.has(id) or str(_ativo.get("id", "")) == id:
		return true
	for item in _fila:
		if item["id"] == id:
			return true
	return false


func foi_concluido(id: String) -> bool:
	return _concluidos.has(id)


func pensamento_atual_id() -> String:
	return str(_ativo.get("id", ""))


func esta_pendente(id: String) -> bool:
	return tem_pensamento(id) and not foi_concluido(id) and not _descartados.has(id)


# Instruções superadas pelo objetivo não contam como falas exibidas.
func descartar(ids: Array[String]) -> void:
	for id in ids:
		if not foi_concluido(id):
			_descartados[id] = true
	for i in range(_fila.size() - 1, -1, -1):
		if ids.has(_fila[i]["id"]):
			_fila.remove_at(i)
	if ids.has(str(_ativo.get("id", ""))):
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = null
		_ativo = {}
		_fase = ""
		_duracao = 0.0
		hide()
		modulate.a = 1.0
	_iniciar_proximo()
	pensamento_concluido.emit()


func mostrar_texto(text: String, id: String = "") -> void:
	if id.is_empty():
		id = "texto:" + text
	enfileirar(id, text)
	var geracao := _geracao
	while not foi_concluido(id) and not _descartados.has(id) and geracao == _geracao:
		await pensamento_concluido


func _iniciar_proximo() -> void:
	if not _ativo.is_empty() or _fila.is_empty():
		return
	_ativo = _fila.pop_front()
	label.text = _ativo["texto"]
	modulate.a = 1.0
	show()
	var tempo := clampf(label.text.length() / maxf(caracteres_por_segundo, 0.001), tempo_minimo, tempo_maximo)
	_iniciar_fase("exibicao", tempo)
	pensamento_iniciado.emit(pensamento_atual_id())


func _iniciar_fase(fase: String, duracao: float) -> void:
	_fase = fase
	_duracao = maxf(duracao, 0.0)
	_tween = create_tween()
	if fase == "exibicao":
		# Mantém a pausa do temporizador original: a leitura conta no menu,
		# mas o fade espera o jogo voltar. Fora da árvore o Tween fica suspenso.
		_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.tween_interval(_duracao)
		_tween.finished.connect(_iniciar_fase.bind("fade", tempo_fade_out))
	else:
		_tween.tween_property(self, "modulate:a", 0.0, _duracao)
		_tween.finished.connect(_concluir)


func _concluir() -> void:
	var id: String = _ativo["id"]
	_concluidos[id] = true
	_ativo = {}
	_fase = ""
	_tween = null
	hide()
	modulate.a = 1.0
	pensamento_finalizado.emit(id)
	pensamento_concluido.emit()
	_iniciar_proximo()


func get_checkpoint_state() -> Dictionary:
	var restante := _duracao
	if _tween != null and _tween.is_valid():
		restante = maxf(0.0, _duracao - _tween.get_total_elapsed_time())
	return {
		"concluidos": _concluidos.duplicate(true),
		"descartados": _descartados.duplicate(true),
		"fila": _fila.duplicate(true),
		"ativo": _ativo.duplicate(true),
		"fase": _fase,
		"restante": restante,
		"alpha": modulate.a
	}


func load_checkpoint_state(data: Dictionary) -> void:
	# Cancela a execução anterior; callbacks antigos não podem concluir a fila nova.
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_geracao += 1
	_concluidos = {}
	_descartados = {}
	_fila.clear()
	_ativo = {}
	_fase = ""
	_duracao = 0.0
	hide()
	modulate.a = 1.0
	var concluidos: Variant = data.get("concluidos", {})
	if concluidos is Dictionary:
		_concluidos = concluidos.duplicate(true)
	var descartados: Variant = data.get("descartados", {})
	if descartados is Dictionary:
		_descartados = descartados.duplicate(true)
	var ativo: Variant = data.get("ativo", {})
	if _item_valido(ativo) and not tem_pensamento(ativo["id"]):
		_ativo = ativo.duplicate(true)
	var fila: Variant = data.get("fila", [])
	if fila is Array:
		for item: Variant in fila:
			if _item_valido(item) and not tem_pensamento(item["id"]):
				_fila.append(item.duplicate(true))
	if not _ativo.is_empty():
		label.text = _ativo["texto"]
		show()
		var fase := str(data.get("fase", "exibicao"))
		if fase != "fade":
			fase = "exibicao"
		modulate.a = clampf(float(data.get("alpha", 1.0)), 0.0, 1.0) if fase == "fade" else 1.0
		_iniciar_fase(fase, float(data.get("restante", tempo_minimo)))
		pensamento_iniciado.emit(pensamento_atual_id())
	else:
		_iniciar_proximo()


func _item_valido(item: Variant) -> bool:
	return (
		item is Dictionary
		and item.get("id") is String
		and not item["id"].is_empty()
		and item.get("texto") is String
	)
