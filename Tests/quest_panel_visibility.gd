extends Node

var failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _finish_thought(balloon: Sprite2D) -> void:
	if balloon._fase == "exibicao" and balloon._tween != null:
		balloon._tween.custom_step(balloon._duracao + 0.01)
	await get_tree().process_frame
	if balloon._fase == "fade" and balloon._tween != null:
		balloon._tween.custom_step(balloon._duracao + 0.01)
	await get_tree().process_frame


func _send_key(keycode: Key) -> void:
	var press_event := InputEventKey.new()
	press_event.keycode = keycode
	press_event.physical_keycode = keycode
	press_event.pressed = true
	Input.parse_input_event(press_event)
	await get_tree().process_frame
	var release_event := InputEventKey.new()
	release_event.keycode = keycode
	release_event.physical_keycode = keycode
	release_event.pressed = false
	Input.parse_input_event(release_event)
	await get_tree().create_timer(0.1).timeout


func _run() -> void:
	SaveGame.clear_save()
	var tree := get_tree()
	get_parent().remove_child(self)
	tree.root.add_child(self)
	get_tree().change_scene_to_file("res://Scenes/andar_hall.tscn")
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	var hall := get_tree().current_scene
	var quest := hall.get_node("QuestController")
	var player: Player = hall.player
	var painel := player.get_node("QUEST_MISSION") as QuestMissionUI
	var empty_dialog_npc := hall.get_node("NPCs/NPC1")
	empty_dialog_npc._on_area_2d_body_entered(player)
	_check(not empty_dialog_npc.get_node("InteractionPrompt").visible, "NPC sem diálogo não mostra nome nem aviso de interação")
	empty_dialog_npc._on_area_2d_body_exited(player)
	_check(painel.get_parent() == player, "painel de tarefas pertence ao Player")
	_check(hall.get_node_or_null("QUEST_MISSION") == null, "hall não mantém painel duplicado")
	quest._hide_scheduled = true
	quest._pos_saida_iniciada = true
	quest._atualizar_linhas_tarefas()
	quest._atualizar_visibilidade()
	_check(painel.visible, "painel permanece visível durante a tarefa de saída")
	_check(painel.rows[2].visible, "M3 usa o nó fixo da árvore do Player")
	quest._on_pensamento_finalizado(quest._pensamento_id("saida"))
	await get_tree().create_timer(5.2).timeout
	_check(painel.visible, "fim da fala de saída não oculta o painel depois de cinco segundos")
	quest._liberar_elevador_terceiro()
	_check(painel.visible, "liberação do terceiro andar mantém o painel visível")
	_check(painel.rows[3].visible, "M4 fixo aparece para ir ao terceiro andar")
	_check(not painel.rows[0].visible and not painel.rows[1].visible and not painel.rows[2].visible, "somente M4 permanece visível após concluir as tarefas anteriores")
	get_tree().paused = true
	_check(not painel.visible, "painel oculta dentro do elevador/pausa")
	get_tree().paused = false
	await get_tree().process_frame
	_check(painel.visible, "painel reaparece ao sair do elevador/pausa")
	painel.hide_during_elevator()
	_check(not painel.visible, "painel fica oculto durante a viagem do elevador")
	scene_manager.change_scene(player, "andar_escritorio")
	await get_tree().scene_changed
	await get_tree().process_frame
	await get_tree().process_frame
	_check(player.get_parent() == get_tree().current_scene, "mesmo Player foi levado ao terceiro andar")
	_check(player.get_node("QUEST_MISSION") == painel, "painel persistiu com o Player entre os andares")
	_check(get_tree().current_scene.get_node_or_null("QUEST_MISSION") == null, "terceiro andar não possui painel duplicado")
	_check(painel.visible, "painel continua visível ao sair do elevador no terceiro andar")
	_check(painel.markers[3].frame == 1, "M4 é concluída ao chegar ao terceiro andar")
	_check(painel.rows[3].visible and not painel.rows[0].visible and not painel.rows[1].visible and not painel.rows[2].visible, "escritório mostra somente a tarefa de subir ao terceiro andar")
	var npc := get_tree().current_scene.get_node("NPCs/NPC1")
	_check(not npc.visible, "NPC começa invisível enquanto o Player observa o escritório vazio")
	_check(not player.balao_de_pensamento.tem_pensamento("office:empty_floor"), "pensamento não aparece imediatamente ao entrar no escritório")
	await get_tree().create_timer(6.1).timeout
	_check(player.balao_de_pensamento.tem_pensamento("office:empty_floor"), "Player pergunta Cadê todo mundo? após seis segundos no escritório vazio")
	await _finish_thought(player.balao_de_pensamento)
	await get_tree().create_timer(1.9).timeout
	_check(not npc.visible, "NPC continua invisível antes de completar dois segundos após a pergunta")
	await get_tree().create_timer(0.2).timeout
	_check(npc.visible and npc.current_path == npc.get_node("Line2D2"), "NPC aparece após dois segundos e inicia o caminho definido")
	var arrival_deadline := Time.get_ticks_msec() + 6000
	while not bool(SaveGame.office_mission_state().get("office_npc_arrived", false)) and Time.get_ticks_msec() < arrival_deadline:
		await get_tree().create_timer(0.05).timeout
	_check(bool(SaveGame.office_mission_state().get("office_npc_arrived", false)), "NPC chega ao fim do caminho da sala do chefe")
	var npc_balloon := npc.get_node("BalaoDePensamento")
	_check(npc_balloon.tem_pensamento("office:npc_boss_shout"), "NPC grita CHEFE! CHEFE! no próprio balão")
	_check(not npc.dialog_enabled, "diálogo permanece bloqueado até o fim do grito")
	await _finish_thought(npc_balloon)
	_check(npc.dialog_enabled, "diálogo é liberado depois do grito")
	_check((painel.rows[3].get_node("Label3") as Label).text == "FALE COM O NPC", "tarefa muda para FALE COM O NPC depois do grito")
	_check(painel.markers[3].frame == 0, "nova tarefa começa pendente")
	npc._on_area_2d_body_entered(player)
	_check(npc.get_node("InteractionPrompt").visible, "NPC com diálogo mostra ESPAÇO: FALAR quando o Player se aproxima")
	await _send_key(KEY_SPACE)
	_check(DialogManager.is_showing_dialog and DialogManager.dialog_box != null and not get_tree().paused, "entrada real de Espaço abre o diálogo sem pausar a árvore do jogo")
	var dialog_box = DialogManager.dialog_box
	await _send_key(KEY_SPACE)
	_check(dialog_box.text_label.text == dialog_box.texts_to_display[0] and not dialog_box.is_typing, "segunda entrada real de Espaço completa o texto")
	await _send_key(KEY_ESCAPE)
	_check(not get_tree().paused and DialogManager.is_showing_dialog, "Esc não abre o menu de pausa durante o diálogo")
	await _send_key(KEY_SPACE)
	await _send_key(KEY_SPACE)
	await _send_key(KEY_SPACE)
	await _send_key(KEY_SPACE)
	await _send_key(KEY_SPACE)
	await get_tree().create_timer(0.4).timeout
	_check(not DialogManager.is_showing_dialog and not get_tree().paused, "Espaço avança todas as falas e fecha o diálogo normalmente")
	_check(bool(SaveGame.office_mission_state().get("office_dialog_finished", false)), "conversa concluída é salva")
	await get_tree().create_timer(0.3).timeout
	_check(painel.markers[3].frame == 1, "tarefa FALE COM O NPC é concluída ao terminar a conversa")
	print("RESULT: ", failures, " failures")
	get_tree().quit(1 if failures > 0 else 0)
