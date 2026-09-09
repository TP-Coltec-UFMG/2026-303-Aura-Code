class_name SceneTrigger
extends Area2D

@export var connected_scene: String
@export	var eh_elevador: bool
@export var andar_atual: int
@onready var painel_elevador: Node2D = $"../PainelElevador"
@onready var controle_de_tempo: Control = $"../UI/Controle_de_tempo"

var ultima_posicao: Vector2

@onready var acesso_liberado: AudioStreamPlayer2D = $"Acesso liberado"
@onready var aceso_negado: AudioStreamPlayer2D = $"Aceso negado"

var andar_elevador_to_change : int 
var dentro_da_area : bool = false
var body_p : Player

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		dentro_da_area = true
		body_p = body


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		dentro_da_area = false
		
func _get_connect_scene_andar_novo(andar : int) -> String:
	if andar == 1:
		return "andar_saida"
	if andar == 2:
		return "andar_hall"
	if andar == 3:
		return "andar_escritorio"
	if andar == 4:
		return "andar_ferramentas"
	if andar == 5:
		return "andar_centro_de_energia"
	if andar == 6:
		return "andar_data_center"
		
	return "andar_invalido"
	
func usar_elevador(andar: int) -> void:
	if eh_elevador and not elevador_liberado():
		return
	if andar == -2:
		if dentro_da_area:
			_ocultar_paineis_tarefas()
			body_p.set_physics_process(true)
			body_p.inventory.hide()
			painel_elevador.resetar_sprites()
			await painel_elevador.animacao()
			body_p.global_position = ultima_posicao
			body_p.inventory.show()
			controle_de_tempo.show()
			$"../UI/PauseMenu".process_mode = Node.PROCESS_MODE_ALWAYS
			_mostrar_paineis_tarefas()
		return
	if andar != andar_atual and eh_elevador:
		if dentro_da_area:
			_concluir_tarefa_do_sexto_andar(andar)
			_ocultar_paineis_tarefas()
			body_p.inventory.hide()
			$Timer.start()
			await $Timer.timeout
			await painel_elevador.animacao()
			body_p.set_physics_process(true)
			$"../UI/PauseMenu".process_mode = Node.PROCESS_MODE_ALWAYS
			scene_manager.change_scene(body_p, _get_connect_scene_andar_novo(andar))
			body_p.inventory.show()
			
	if (andar == andar_atual and eh_elevador):
		if dentro_da_area:
			_ocultar_paineis_tarefas()
			body_p.set_physics_process(true)
			body_p.inventory.hide()
			painel_elevador.resetar_sprites()
			await painel_elevador.animacao()
			body_p.global_position = ultima_posicao
			$"../UI/PauseMenu".process_mode = Node.PROCESS_MODE_ALWAYS
			body_p.inventory.show()
			controle_de_tempo.show()
			_mostrar_paineis_tarefas()
			
			
func get_ultima_posicao() -> Vector2:
	return ultima_posicao

func _input(event: InputEvent) -> void:
	
	if event.is_action_pressed("interact") and eh_elevador and dentro_da_area:
		if not elevador_liberado():
			return

		ultima_posicao = body_p.global_position
		body_p.set_physics_process(false)
		body_p.global_position += Vector2(-20, -200)
		painel_elevador.resetar_sprites()
		$"../UI/PauseMenu".process_mode = Node.PROCESS_MODE_DISABLED
		painel_elevador.visible = true
		controle_de_tempo.hide()
		_ocultar_paineis_tarefas()
		get_tree().paused = true

	if event.is_action_pressed("interact") and dentro_da_area and not eh_elevador:
		if _tem_cartao_compativel() or _sala_do_chefe_foi_hackeada():
			acesso_liberado.play()
			await acesso_liberado.finished
			if dentro_da_area:
				_preparar_saida_da_sala_do_chefe()
				_registrar_acesso_a_sala_do_chefe()
				scene_manager.change_scene(body_p, connected_scene)
		elif _pode_hackear_sala_do_chefe():
			Progresso.iniciar_hack_da_sala_do_chefe(body_p)
		else:
			aceso_negado.play()
			print("Acesso Negado")


func _tem_cartao_compativel() -> bool:
	if not body_p.inventory.get_item_on_inventary("cartao") or not body_p.usando_cartao:
		return false
	var tipo_cartao: int = int(body_p.inventory.get_item_control("cartao").tipo)
	var tipo_sala_acessando := 1
	if connected_scene.containsn("chefe"):
		tipo_sala_acessando = 3
	elif connected_scene.containsn("forte"):
		tipo_sala_acessando = 2
	return tipo_cartao >= tipo_sala_acessando


func _pode_hackear_sala_do_chefe() -> bool:
	return (
		connected_scene.containsn("chefe")
		and body_p.inventory.get_item_on_inventary("laptop")
		and body_p.inventory.get_item_on_inventary("cabo")
		and not _sala_do_chefe_foi_hackeada()
	)


func _sala_do_chefe_foi_hackeada() -> bool:
	return (
		connected_scene.containsn("chefe")
		and bool(SaveGame.office_mission_state(body_p).get("office_boss_room_hacked", false))
	)


func _registrar_acesso_a_sala_do_chefe() -> void:
	if not connected_scene.containsn("chefe"):
		return
	var estado := SaveGame.office_mission_state(body_p)
	estado["office_boss_room_access_found"] = true
	SaveGame.save_global_state("hall_quest_01", estado)


func _preparar_saida_da_sala_do_chefe() -> void:
	if connected_scene != "andar_escritorio":
		return
	var scene := get_parent()
	if scene != null and scene.has_method("prepare_return_to_office"):
		scene.call("prepare_return_to_office")


func _concluir_tarefa_do_sexto_andar(andar: int) -> void:
	if andar != 6:
		return
	var state: Dictionary = SaveGame.office_mission_state(body_p)
	if not bool(state.get("office_data_center_task_active", false)):
		return
	if bool(state.get("office_data_center_task_completed", false)):
		return
	state["office_data_center_task_completed"] = true
	SaveGame.save_global_state("hall_quest_01", state)
	var quest_ui := _obter_painel_tarefas()
	if quest_ui != null:
		quest_ui.show_go_to_sixth_floor_task(true, true)
			


func elevador_liberado() -> bool:
	if not is_inside_tree():
		return false
	if not get_tree().current_scene.scene_file_path.ends_with("andar_hall.tscn"):
		return true
	return bool(SaveGame.office_mission_state().get("elevator_third_floor_unlocked", false))


func _ocultar_paineis_tarefas() -> void:
	var painel := _obter_painel_tarefas()
	if painel != null:
		painel.hide_during_elevator()


func _mostrar_paineis_tarefas() -> void:
	var painel := _obter_painel_tarefas()
	if painel != null:
		painel.restore_after_elevator()


func _obter_painel_tarefas() -> QuestMissionUI:
	var jogador := body_p
	if not is_instance_valid(jogador):
		jogador = get_tree().get_first_node_in_group("player") as Player
	if not is_instance_valid(jogador):
		return null
	return jogador.get_node_or_null("QUEST_MISSION") as QuestMissionUI
