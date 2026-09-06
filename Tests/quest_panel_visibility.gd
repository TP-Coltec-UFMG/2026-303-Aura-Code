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
	print("RESULT: ", failures, " failures")
	get_tree().quit(1 if failures > 0 else 0)
