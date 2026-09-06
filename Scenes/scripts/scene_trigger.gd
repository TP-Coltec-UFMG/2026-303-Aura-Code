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

	if event.is_action_pressed("interact") and dentro_da_area and body_p.inventory.get_item_on_inventary("cartao") and body_p.usando_cartao and not eh_elevador:
		var tipo_cartao = body_p.inventory.get_item_control("cartao").tipo
		var tipo_sala_acessando
		
		if connected_scene.containsn("chefe"):
			tipo_sala_acessando = 3
		elif connected_scene.containsn("forte"):
			tipo_sala_acessando = 2
		else:
			tipo_sala_acessando = 1
		
		if tipo_cartao >= tipo_sala_acessando:
			acesso_liberado.play()
			await  acesso_liberado.finished
			if dentro_da_area:
				scene_manager.change_scene(body_p, connected_scene)
		else:
			aceso_negado.play()
			print("Acesso Negado")
			


func elevador_liberado() -> bool:
	if not is_inside_tree():
		return false
	if not get_tree().current_scene.scene_file_path.ends_with("andar_hall.tscn"):
		return true
	return bool(SaveGame.office_mission_state().get("elevator_third_floor_unlocked", false))


func _ocultar_paineis_tarefas() -> void:
	for nome in [&"QUEST_MISSION", &"OfficeMission"]:
		var painel := get_tree().current_scene.get_node_or_null(String(nome)) as CanvasLayer
		if painel != null:
			painel.hide()


func _mostrar_paineis_tarefas() -> void:
	for nome in [&"QUEST_MISSION", &"OfficeMission"]:
		var painel := get_tree().current_scene.get_node_or_null(String(nome)) as CanvasLayer
		if painel != null and painel.has_method("_atualizar_visibilidade"):
			painel.call("_atualizar_visibilidade")
		elif painel != null and painel.has_method("atualizar"):
			painel.call("atualizar", body_p)
