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
	var quest := get_tree().current_scene.get_node("QUEST_MISSION")
	quest._hide_scheduled = true
	quest._pos_saida_iniciada = true
	quest._atualizar_linhas_tarefas()
	quest._atualizar_visibilidade()
	_check(quest.visible, "painel permanece visível durante a tarefa de saída")
	_check(quest.get_node("VBoxContainer/HBoxContainer3").visible, "M3 usa o nó fixo da árvore")
	quest._on_pensamento_finalizado(quest._pensamento_id("saida"))
	await get_tree().create_timer(5.2).timeout
	_check(quest.visible, "fim da fala de saída não oculta o painel depois de cinco segundos")
	quest._liberar_elevador_terceiro()
	_check(quest.visible, "liberação do terceiro andar mantém o painel visível")
	_check(quest.get_node("VBoxContainer/HBoxContainer4").visible, "M4 fixo aparece para ir ao terceiro andar")
	get_tree().paused = true
	_check(not quest.visible, "painel oculta dentro do elevador/pausa")
	get_tree().paused = false
	await get_tree().process_frame
	_check(quest.visible, "painel reaparece ao sair do elevador/pausa")
	print("RESULT: ", failures, " failures")
	get_tree().quit(1 if failures > 0 else 0)
