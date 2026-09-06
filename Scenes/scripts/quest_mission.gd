extends CanvasLayer

@export var save_id: String = "hall_quest_01"

@onready var M2: AnimatedSprite2D = (
	$VBoxContainer/HBoxContainer/AnimatedSprite2D
)
@onready var M1: AnimatedSprite2D = (
	$VBoxContainer/HBoxContainer2/AnimatedSprite2D
)
@onready var M3: AnimatedSprite2D = $VBoxContainer/HBoxContainer3/AnimatedSprite2D
@onready var M4: AnimatedSprite2D = $VBoxContainer/HBoxContainer4/AnimatedSprite2D


var man_player: Player
var _inicializado: bool = false
signal orientacao_elevador_iniciada
signal pensamento_extintor_iniciado
var orientar_elevador: bool = false
var orientar_extintor: bool = false

var f1_acesso: bool = true
var f2_acesso: bool = true
var f3_acesso: bool = true

var M1_feito: bool = false
var M2_feito: bool = false

var _hide_scheduled: bool = false
var _todos_sairam: bool = false
var _pos_saida_iniciada: bool = false
var _dica_mostrada: bool = false
var _saida_pendente: int = 0
var _evacuacao_ativa: bool = false
var _elevador_terceiro_liberado: bool = false
var _chegou_terceiro_andar: bool = false



func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PAUSED:
			$"../UI/Controle_de_tempo".hide()
			hide()

		NOTIFICATION_UNPAUSED:
			$"../UI/Controle_de_tempo".show()

			_atualizar_visibilidade()


func _ready() -> void:
	hide()
	# BaseScene escolhe o Player persistente e aplica o checkpoint no _ready.
	call_deferred("_inicializar")


func _inicializar() -> void:
	man_player = get_parent().player as Player
	if not is_instance_valid(man_player):
		return

	_restore_progress()
	_apply_saved_visuals()
	_atualizar_linhas_tarefas()
	_inicializado = true
	man_player.balao_de_pensamento.pensamento_finalizado.connect(_on_pensamento_finalizado)
	man_player.balao_de_pensamento.pensamento_iniciado.connect(_on_pensamento_iniciado)

	MusicController._start_som_de_fundo()
	MusicController._stop_bg_ambient()
	MusicController._set_volume_som_de_fundo(1.0)
	_descartar_instrucoes_obsoletas()
	# O Player pode ter restaurado a fala antes da conexão dos sinais da missão.
	_on_pensamento_iniciado(man_player.balao_de_pensamento.pensamento_atual_id())
	man_player.balao_de_pensamento.atualizar_texto(
		_pensamento_id("pos_saida_2"),
		"Talvez eu deveria ir na sala do escritório (3º andar)"
	)
	if _elevador_terceiro_liberado:
		_atualizar_tarefa_terceiro()

	if _hide_scheduled:
		_iniciar_espera_npcs()
		_start_npc_exit_paths(true)
		_atualizar_visibilidade()
		return

	# Registra a sequência inteira, inclusive as falas que ainda não começaram.
	_pensar("intro_1", "O que está acontecendo?")
	_pensar("intro_2", "Temos que sair desse andar!")
	_pensar("intro_4", "Preciso de um extintor.")
	_atualizar_visibilidade()
	_tentar_finalizar_missao()


func _pensamento_id(id: String) -> String:
	return "hall:" + save_id + ":" + id


func _pensar(id: String, texto: String) -> void:
	man_player.balao_de_pensamento.enfileirar(_pensamento_id(id), texto)


func _descartar_instrucoes_obsoletas() -> void:
	# Remove também a fala antiga quando ela vier ativa ou enfileirada no save.
	var ids: Array[String] = [_pensamento_id("intro_3")]
	if M1_feito:
		ids.append_array([_pensamento_id("intro_4"), _pensamento_id("aviso_1"), _pensamento_id("aviso_2")])
	if M2_feito:
		ids.append(_pensamento_id("pedras"))
	if M1_feito and M2_feito:
		ids.append_array([_pensamento_id("intro_1"), _pensamento_id("intro_2"), _pensamento_id("intro_3")])
	if not ids.is_empty():
		man_player.balao_de_pensamento.descartar(ids)


func _atualizar_visibilidade() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not _inicializado or get_tree().paused:
		return
	var balao = man_player.balao_de_pensamento
	visible = (
		balao.foi_concluido(_pensamento_id("intro_2"))
		or _hide_scheduled
		or _elevador_terceiro_liberado
	)


func _on_pensamento_iniciado(id: String) -> void:
	if id == _pensamento_id("intro_2") and not orientar_elevador:
		orientar_elevador = true
		orientacao_elevador_iniciada.emit()
	if id == _pensamento_id("intro_4") and not orientar_extintor:
		orientar_extintor = true
		pensamento_extintor_iniciado.emit()


func _on_pensamento_finalizado(id: String) -> void:
	if id == _pensamento_id("intro_2"):
		_atualizar_visibilidade()
	elif id == _pensamento_id("saida"):
		_atualizar_visibilidade()
	elif id == _pensamento_id("pos_saida_2"):
		_liberar_elevador_terceiro()

func _liberar_elevador_terceiro() -> void:
	if _elevador_terceiro_liberado:
		return
	_elevador_terceiro_liberado = true
	var estado := SaveGame.office_mission_state()
	estado["elevator_third_floor_unlocked"] = true
	estado["indicator_remaining"] = 10.0
	SaveGame.save_global_state(save_id, estado)
	_save_progress_and_checkpoint()
	_instanciar_indicador_final()
	_atualizar_tarefa_terceiro()
	_atualizar_visibilidade()


func _atualizar_tarefa_terceiro() -> void:
	var linha := $VBoxContainer/HBoxContainer4
	var texto := linha.get_node("Label3") as Label
	texto.text = "IR PARA O TERCEIRO ANDAR"
	linha.show()
	if _chegou_terceiro_andar:
		_set_completed_frame(M4)
	else:
		M4.stop()
		M4.animation = &"default"
		M4.frame = 0


func _atualizar_linhas_tarefas() -> void:
	var linha_saida := $VBoxContainer/HBoxContainer3
	linha_saida.visible = _hide_scheduled
	if _hide_scheduled:
		linha_saida.get_node("Label3").text = "ESPERE TODO MUNDO SAIR"
		if _todos_sairam:
			_set_completed_frame(M3)
		else:
			M3.stop()
			M3.animation = &"default"
			M3.frame = 0
	$VBoxContainer/HBoxContainer4.visible = _elevador_terceiro_liberado
	if _elevador_terceiro_liberado:
		_atualizar_tarefa_terceiro()


func _instanciar_indicador_final() -> void:
	if float(SaveGame.office_mission_state().get("indicator_remaining", 0.0)) <= 0.0:
		return
	var pai := get_parent().get_node_or_null("Interativos")
	if pai == null or pai.has_node("ElevatorIndicator"):
		return
	var antigo := pai.get_node_or_null("Line2D")
	if antigo != null:
		antigo._liberar_indicador()
	orientar_elevador = true
	var novo := preload("res://Scenes/elevator_indicator.tscn").instantiate()
	novo.get_node("Line2D").ciclo_final = true
	pai.add_child(novo)


func _on_fogo_3_fogo_apagou() -> void:
	if not f1_acesso:
		return

	f1_acesso = false

	_update_fire_task()
	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


func _on_fogo_5_fogo_apagou() -> void:
	if not f2_acesso:
		return

	f2_acesso = false

	_update_fire_task()
	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


func _on_fogo_6_fogo_apagou() -> void:
	if not f3_acesso:
		return

	f3_acesso = false

	_update_fire_task()
	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if not body is ObjetoEmpurravel:
		return

	if M2_feito:
		return

	M2_feito = true
	M2.play(&"default")

	if not M1_feito:
		_pensar("aviso_1", "Tenho que apagar todos os fogos!")
		_pensar("aviso_2", "Não é seguro passar assim.")

	if not _tentar_finalizar_missao():
		_save_progress_and_checkpoint()


func _update_fire_task() -> void:
	if f1_acesso:
		return

	if f2_acesso:
		return

	if f3_acesso:
		return

	if M1_feito:
		return

	M1_feito = true
	M1.play(&"default")

	if not M2_feito:
		_pensar("pedras", "Só preciso tirar essas pedras do caminho!")


func _tentar_finalizar_missao() -> bool:
	if not _inicializado:
		return false
	_descartar_instrucoes_obsoletas()
	if not M1_feito:
		return false

	if not M2_feito:
		return false

	if _hide_scheduled:
		return false

	_hide_scheduled = true

	_start_npc_exit_paths()
	_pensar("saida", "Vai, vai, vai, vai! Corram! Corram todos! Saiam!")
	_pos_saida_iniciada = true
	_iniciar_espera_npcs()
	_save_progress_and_checkpoint()
	return true


func _start_npc_exit_paths(legacy_restore: bool = false) -> void:
	var npcs := get_node_or_null("../NPCs")

	if npcs == null:
		return

	for npc in npcs.get_children():
		if npc.is_queued_for_deletion():
			continue

		var path := npc.get_node_or_null("Line2D2") as NPCPath

		if path == null:
			continue

		if legacy_restore:
			if not npc.get_script():
				continue

			if npc.get("checkpoint_restored") != false:
				continue

			path.start_path()

			var points: Variant = npc.get("path_points")

			if points is Array and not points.is_empty():
				npc.global_position = points[0]

		else:
			path.start_path()


func _iniciar_espera_npcs() -> void:
	$VBoxContainer/HBoxContainer3.show()
	if _todos_sairam:
		_concluir_saida_depois_da_animacao(null)
		return
	$VBoxContainer/HBoxContainer3/Label3.text = "ESPERE TODO MUNDO SAIR"
	M3.stop()
	M3.animation = &"default"
	M3.frame = 0
	M3.frame_progress = 0.0
	$VBoxContainer/HBoxContainer3.show()
	var npcs := get_node_or_null("../NPCs")
	_saida_pendente = 0
	_evacuacao_ativa = true
	if npcs != null:
		for npc in npcs.get_children():
			if npc.is_queued_for_deletion():
				continue
			_saida_pendente += 1
			if npc.has_signal("npc_saiu"):
				if not npc.npc_saiu.is_connected(_on_npc_saiu):
					npc.npc_saiu.connect(_on_npc_saiu, CONNECT_ONE_SHOT)
			elif not npc.tree_exiting.is_connected(_on_npc_saiu):
				npc.tree_exiting.connect(_on_npc_saiu, CONNECT_ONE_SHOT)
	if _saida_pendente == 0:
		_concluir_saida_npcs()


func _on_npc_saiu() -> void:
	if not _evacuacao_ativa or not is_inside_tree():
		return
	_saida_pendente = maxi(_saida_pendente - 1, 0)
	if _saida_pendente == 0:
		_concluir_saida_npcs()


func _concluir_saida_npcs() -> void:
	if _todos_sairam:
		return
	_todos_sairam = true
	_evacuacao_ativa = false
	M3.play("default")
	_concluir_saida_depois_da_animacao(M3)


func _concluir_saida_depois_da_animacao(marcador: AnimatedSprite2D) -> void:
	if marcador != null:
		await marcador.animation_finished
	if not is_inside_tree() or is_queued_for_deletion() or not _pos_saida_iniciada:
		return
	_pensar("pos_saida_1", "Eu tenho que investigar isso.")
	_pensar("pos_saida_2", "Talvez eu deveria ir na sala do escritório (3º andar)")
	_save_progress_and_checkpoint()


func _save_progress_and_checkpoint() -> void:
	SaveGame.save_object_state(
		save_id,
		{
			"fire_1_done": not f1_acesso,
			"fire_2_done": not f2_acesso,
			"fire_3_done": not f3_acesso,
			"task_fire_done": M1_feito,
			"task_elevator_done": M2_feito,
			"exit_started": _hide_scheduled,
			"everyone_out": _todos_sairam,
			"post_exit_started": _pos_saida_iniciada,
			"office_hint_shown": _dica_mostrada
			,"elevator_third_floor_unlocked": _elevador_terceiro_liberado
			,"arrived_third_floor": _chegou_terceiro_andar
		}
	)

	var player := get_tree().get_first_node_in_group("player") as Player

	if player != null and player.checkpoint_enabled:
		SaveGame.create_checkpoint(player)


func _restore_progress() -> void:
	var saved_value: Variant = SaveGame.load_object_state(save_id)

	if saved_value is Dictionary:
		var saved_state: Dictionary = saved_value

		f1_acesso = not bool(
			saved_state.get("fire_1_done", false)
		)

		f2_acesso = not bool(
			saved_state.get("fire_2_done", false)
		)

		if saved_state.has("fire_3_done"):
			f3_acesso = not bool(
				saved_state.get("fire_3_done", false)
			)
		else:
			f3_acesso = not _is_saved_fire_extinguished("fogo06")

		M1_feito = bool(
			saved_state.get("task_fire_done", false)
		)

		M2_feito = bool(
			saved_state.get("task_elevator_done", false)
		)
		# Saves antigos só registravam as tarefas, sem a etapa de saída.
		_hide_scheduled = bool(saved_state.get("exit_started", M1_feito and M2_feito))
		_todos_sairam = bool(saved_state.get("everyone_out", false))
		_pos_saida_iniciada = bool(saved_state.get("post_exit_started", false))
		_dica_mostrada = bool(saved_state.get("office_hint_shown", false))
		_elevador_terceiro_liberado = bool(saved_state.get("elevator_third_floor_unlocked", false))
		_chegou_terceiro_andar = bool(saved_state.get("arrived_third_floor", false))

	else:
		f1_acesso = not _is_saved_fire_extinguished("fogo04")
		f2_acesso = not _is_saved_fire_extinguished("fogo05")
		f3_acesso = not _is_saved_fire_extinguished("fogo06")

		M1_feito = (
			not f1_acesso
			and not f2_acesso
			and not f3_acesso
		)
	var global_state: Variant = SaveGame.office_mission_state(man_player)
	if global_state is Dictionary:
		_elevador_terceiro_liberado = bool(global_state.get("elevator_third_floor_unlocked", _elevador_terceiro_liberado))
		_chegou_terceiro_andar = bool(global_state.get("arrived_third_floor", _chegou_terceiro_andar))

	if not f1_acesso and not f2_acesso and not f3_acesso:
		M1_feito = true


func _is_saved_fire_extinguished(fire_save_id: String) -> bool:
	var fire_state: Variant = SaveGame.load_object_state(fire_save_id)

	return (
		fire_state is Dictionary
		and bool(fire_state.get("apagado", false))
	)


func _apply_saved_visuals() -> void:
	M1.stop()
	M2.stop()
	M3.stop()
	M4.stop()

	M1.frame = 0
	M2.frame = 0

	if M1_feito:
		_set_completed_frame(M1)

	if M2_feito:
		_set_completed_frame(M2)
	if _todos_sairam:
		_set_completed_frame(M3)
	if _chegou_terceiro_andar:
		_set_completed_frame(M4)


func _set_completed_frame(marker: AnimatedSprite2D) -> void:
	if marker.sprite_frames == null:
		return

	var frame_count := marker.sprite_frames.get_frame_count(
		&"default"
	)

	marker.animation = &"default"
	marker.frame = maxi(frame_count - 1, 0)
