extends Node

const FILE_PATH: String = "user://SaveFileGameState.json"
const CHARACTER_SELECTION_SCENE: String = "res://Scenes/slectionpage.tscn"
const MAIN_MENU_SCENE: String = "res://Scenes/principal.tscn"

const INVALID_CHECKPOINT_POS: Vector2 = Vector2(-999, -999)
const SAVE_VERSION: int = 6
const CHECKPOINT_ACTOR_GROUP: StringName = &"checkpoint_actors"
const CHECKPOINT_ACTOR_BUCKET: String = "__checkpoint_actors"
const CHECKPOINT_ACTOR_META: StringName = &"checkpoint_actor_identity"

# Tempo registrado no último checkpoint.
var tempo_restante: float = -1.0

# Tempo atual da partida, mantido durante mudanças de andar.
var tempo_atual: float = -1.0

var save_data: Dictionary = {}

var checkpoint_scene_path: String = ""
var checkpoint_player_scene_path: String = ""
var checkpoint_pos: Vector2 = INVALID_CHECKPOINT_POS
var state_player: Dictionary = {}
var checkpoint_world_state: Dictionary = {}
var checkpoint_progress: Dictionary = {}
var checkpoint_audio_state: Dictionary = {}

var restore_checkpoint_pending: bool = false
var restore_audio_pending: bool = false


func _ready() -> void:
	_load()


func _save() -> void:
	if checkpoint_scene_path.is_empty():
		return

	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.WRITE)

	if file == null:
		push_error("Não foi possível salvar o checkpoint.")
		return

	var data: Dictionary = {
		"version": SAVE_VERSION,
		"scene_path": checkpoint_scene_path,
		"player_scene_path": checkpoint_player_scene_path,
		"checkpoint_pos": checkpoint_pos,
		"state_player": state_player.duplicate(true),
		"world_state": checkpoint_world_state.duplicate(true),
		"progress": checkpoint_progress.duplicate(true),
		"audio_state": checkpoint_audio_state.duplicate(true),
		"tempo_restante": tempo_restante
	}

	file.store_var(data)
	file.close()


func _load() -> void:
	if not FileAccess.file_exists(FILE_PATH):
		return

	var file: FileAccess = FileAccess.open(FILE_PATH, FileAccess.READ)

	if file == null:
		return

	var loaded_data: Variant = file.get_var()
	file.close()

	if not loaded_data is Dictionary:
		return

	var data: Dictionary = loaded_data

	if not data.has("scene_path"):
		return

	checkpoint_scene_path = str(
		data.get("scene_path", "")
	)

	checkpoint_player_scene_path = str(
		data.get("player_scene_path", "")
	)

	var loaded_position: Variant = data.get(
		"checkpoint_pos",
		INVALID_CHECKPOINT_POS
	)

	if loaded_position is Vector2:
		checkpoint_pos = loaded_position

	var loaded_player: Variant = data.get(
		"state_player",
		{}
	)

	if loaded_player is Dictionary:
		state_player = loaded_player.duplicate(true)

	var loaded_world: Variant = data.get(
		"world_state",
		{}
	)

	if loaded_world is Dictionary:
		checkpoint_world_state = loaded_world.duplicate(true)

	var loaded_progress: Variant = data.get(
		"progress",
		{}
	)

	if loaded_progress is Dictionary:
		checkpoint_progress = loaded_progress.duplicate(true)

	var loaded_audio: Variant = data.get(
		"audio_state",
		{}
	)

	checkpoint_audio_state.clear()

	if loaded_audio is Dictionary:
		checkpoint_audio_state = loaded_audio.duplicate(true)

	tempo_restante = float(
		data.get("tempo_restante", -1.0)
	)

	save_data = checkpoint_world_state.duplicate(true)


func create_player_from_checkpoint() -> Player:
	if checkpoint_player_scene_path.is_empty():
		push_error("Checkpoint não possui uma cena de Player salva.")
		return null

	var player_scene: PackedScene = load(
		checkpoint_player_scene_path
	) as PackedScene

	if player_scene == null:
		push_error(
			"Não foi possível carregar o Player: "
			+ checkpoint_player_scene_path
		)
		return null

	var novo_player: Player = player_scene.instantiate() as Player

	if novo_player == null:
		push_error(
			"A cena salva não possui Player como nó raiz: "
			+ checkpoint_player_scene_path
		)
		return null

	return novo_player


func capturar_tempo_atual() -> void:
	var temporizador: Node = get_tree().get_first_node_in_group(
		"temporizador_jogo"
	)

	if not is_instance_valid(temporizador):
		return

	if temporizador.has_method("get_tempo_restante"):
		tempo_atual = float(
			temporizador.call("get_tempo_restante")
		)


func create_checkpoint(
	player: Player,
	audio_state_override: Dictionary = {}
) -> void:
	if player == null:
		return

	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return

	checkpoint_scene_path = current_scene.scene_file_path
	checkpoint_player_scene_path = player.scene_file_path
	checkpoint_pos = player.global_position

	state_player = player.get_checkpoint_state().duplicate(true)
	capture_checkpoint_actors(current_scene)
	checkpoint_world_state = save_data.duplicate(true)

	checkpoint_progress = {
		"job": Configs.configs.get("job", ""),
		"character": Configs.configs.get("character", ""),
		"difficulty": Configs.configs.get("difficulty", "")
	}

	if audio_state_override.is_empty():
		checkpoint_audio_state = (
			MusicController.get_checkpoint_state().duplicate(true)
		)
	else:
		# O menu de pausa captura isto antes de pausar a SceneTree. Assim o
		# silêncio temporário do menu nunca substitui o áudio real da partida.
		checkpoint_audio_state = audio_state_override.duplicate(true)

	capturar_tempo_atual()
	tempo_restante = tempo_atual

	_save()


func _save_state_game(body: Node2D) -> void:
	if body is Player:
		create_checkpoint(body as Player)


func has_checkpoint() -> bool:
	return (
		not checkpoint_scene_path.is_empty()
		and checkpoint_pos != INVALID_CHECKPOINT_POS
		and not state_player.is_empty()
	)


func persist_checkpoint() -> void:
	# Regrava somente o checkpoint já capturado. Nunca consulta o áudio do menu.
	_save()


func load_last_checkpoint() -> bool:
	if not has_checkpoint():
		return false

	save_data = checkpoint_world_state.duplicate(true)

	_restore_progress_config()

	# Descarta o tempo atual e recupera o tempo do checkpoint.
	tempo_atual = tempo_restante
	restore_checkpoint_pending = true
	restore_audio_pending = not checkpoint_audio_state.is_empty()

	if restore_audio_pending:
		# Mantém os playbacks vivos, mas pausados, durante a troca. A restauração
		# usa seek() neles depois que a nova cena terminar de inicializar.
		MusicController.begin_checkpoint_restore()
	else:
		# Save antigo: não há posição para restaurar, então a cena pode iniciar
		# suas músicas normalmente.
		MusicController.stop_all_audio()

	scene_manager.player = null
	scene_manager.last_scene_name = ""

	var scene_changed_callback := Callable(
		self,
		"_on_checkpoint_scene_changed"
	)

	if get_tree().scene_changed.is_connected(scene_changed_callback):
		get_tree().scene_changed.disconnect(scene_changed_callback)

	if restore_audio_pending:
		get_tree().scene_changed.connect(
			scene_changed_callback,
			CONNECT_ONE_SHOT
		)

	var erro: Error = get_tree().change_scene_to_file(
		checkpoint_scene_path
	)

	if erro != OK:
		restore_checkpoint_pending = false
		restore_audio_pending = false

		if get_tree().scene_changed.is_connected(scene_changed_callback):
			get_tree().scene_changed.disconnect(scene_changed_callback)

		push_error(
			"Não foi possível carregar a cena do checkpoint: "
			+ checkpoint_scene_path
		)
		return false

	return true


func apply_pending_checkpoint(player: Player) -> bool:
	if not restore_checkpoint_pending:
		return false

	if player == null:
		return false

	player.global_position = checkpoint_pos
	player.load_checkpoint_state(state_player.duplicate(true))

	restaurar_tempo_checkpoint()

	restore_checkpoint_pending = false
	return true


func _on_checkpoint_scene_changed() -> void:
	_restore_audio_after_scene_ready()


func _restore_audio_after_scene_ready() -> void:
	# Alguns nós da fase iniciam alarme/música em _ready(). Esperar um frame
	# garante que nenhum desses play() volte a faixa para zero após o restore.
	await get_tree().process_frame

	if not restore_audio_pending:
		return

	MusicController.load_checkpoint_state(
		checkpoint_audio_state.duplicate(true)
	)
	restore_audio_pending = false


func restaurar_tempo_checkpoint() -> void:
	if tempo_restante < 0.0:
		return

	tempo_atual = tempo_restante

	var temporizador: Node = get_tree().get_first_node_in_group(
		"temporizador_jogo"
	)

	if not is_instance_valid(temporizador):
		push_warning(
			"Temporizador não encontrado ao carregar o checkpoint."
		)
		return

	if temporizador.has_method("carregar_tempo_restante"):
		temporizador.call(
			"carregar_tempo_restante",
			tempo_restante
		)


func _restore_progress_config() -> void:
	if checkpoint_progress.has("job"):
		Configs.configs["job"] = checkpoint_progress["job"]

	if checkpoint_progress.has("character"):
		Configs.configs["character"] = checkpoint_progress["character"]

	if checkpoint_progress.has("difficulty"):
		Configs.configs["difficulty"] = checkpoint_progress["difficulty"]


## Registre após inicializar o movimento. Retorna true se encontrou estado salvo.
## A identidade padrão é o caminho do nó relativo à cena, nunca um instance_id.
func register_checkpoint_actor(actor: Node, actor_id: String = "") -> bool:
	if not actor.has_method("get_checkpoint_state") or not actor.has_method("load_checkpoint_state"):
		push_error("Participante de checkpoint sem métodos de captura/restauração: " + str(actor.name))
		return false
	var scene := _checkpoint_actor_scene(actor)
	if scene == null:
		return false
	var identity: Array[String] = [scene.scene_file_path, actor_id]
	if actor_id.is_empty():
		identity[1] = str(scene.get_path_to(actor))
	for other in get_tree().get_nodes_in_group(CHECKPOINT_ACTOR_GROUP):
		if other != actor and not other.is_queued_for_deletion() and other.get_meta(CHECKPOINT_ACTOR_META, []) == identity:
			push_error("Identidade de NPC duplicada na cena: " + identity[1])
			return false
	actor.set_meta(CHECKPOINT_ACTOR_META, identity)
	actor.add_to_group(CHECKPOINT_ACTOR_GROUP)
	var saved: Variant = _checkpoint_actor_states(identity[0]).get(identity[1])
	if not saved is Dictionary:
		return false
	if saved.get("removed", false):
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		if actor is CanvasItem:
			(actor as CanvasItem).hide()
		actor.queue_free()
		return true
	var state: Variant = saved.get("state")
	if not state is Dictionary:
		return false
	actor.call("load_checkpoint_state", state.duplicate(true))
	return true


func _checkpoint_actor_scene(actor: Node) -> Node:
	# current_scene pode ainda não estar atribuído durante o _ready dos filhos.
	var scene: Node = null
	var ancestor: Node = actor
	while ancestor != null and ancestor != get_tree().root:
		if not ancestor.scene_file_path.is_empty():
			scene = ancestor
		ancestor = ancestor.get_parent()
	return scene


func _checkpoint_actor_states(scene_path: String) -> Dictionary:
	var scene_state: Variant = save_data.get(scene_path, {})
	if scene_state is Dictionary:
		var actors: Variant = scene_state.get(CHECKPOINT_ACTOR_BUCKET, {})
		if actors is Dictionary:
			return actors
	return {}


func _store_checkpoint_actor(actor: Node, state: Dictionary) -> void:
	if not actor.has_meta(CHECKPOINT_ACTOR_META):
		return
	var identity: Array = actor.get_meta(CHECKPOINT_ACTOR_META)
	var scene_path: String = identity[0]
	if not save_data.get(scene_path) is Dictionary:
		save_data[scene_path] = {}
	var actors := _checkpoint_actor_states(scene_path)
	actors[identity[1]] = state
	save_data[scene_path][CHECKPOINT_ACTOR_BUCKET] = actors


## Captura em memória apenas nos checkpoints e antes de trocar de andar.
func capture_checkpoint_actors(scene: Node) -> void:
	if scene == null:
		return
	for actor in get_tree().get_nodes_in_group(CHECKPOINT_ACTOR_GROUP):
		if actor.is_queued_for_deletion() or not (actor == scene or scene.is_ancestor_of(actor)):
			continue
		var state: Variant = actor.call("get_checkpoint_state")
		if state is Dictionary:
			_store_checkpoint_actor(actor, {"state": state.duplicate(true)})


## Chame antes de queue_free quando a remoção faz parte da progressão.
## Não capture no _exit_tree: isso sobrescreveria estados ao morrer/recarregar.
func mark_checkpoint_actor_removed(actor: Node) -> void:
	_store_checkpoint_actor(actor, {"removed": true})
	actor.remove_from_group(CHECKPOINT_ACTOR_GROUP)


func save_object_state(object_id: String, state: Variant) -> void:
	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return

	var scene_path: String = current_scene.scene_file_path

	if scene_path.is_empty():
		return

	if not save_data.has(scene_path):
		save_data[scene_path] = {}

	save_data[scene_path][object_id] = state


func load_object_state(object_id: String) -> Variant:
	var current_scene: Node = get_tree().current_scene

	if current_scene == null:
		return null

	var scene_path: String = current_scene.scene_file_path

	if not save_data.has(scene_path):
		return null

	return save_data[scene_path].get(object_id, null)

func save_global_state(object_id: String, state: Variant) -> void:
	if not save_data.has("__global"):
		save_data["__global"] = {}
	save_data["__global"][object_id] = state

func load_global_state(object_id: String) -> Variant:
	var global_state: Variant = save_data.get("__global", {})
	if global_state is Dictionary:
		return global_state.get(object_id, null)
	return null


func set_object_collected(object_id: String) -> void:
	save_object_state(object_id, true)


func is_object_collected(object_id: String) -> bool:
	return load_object_state(object_id) == true


func save_current_session(
	audio_state_override: Dictionary = {}
) -> bool:
	var current_scene := get_tree().current_scene

	# O menu mantém os players globais pausados. Uma notificação de fechamento
	# recebida aqui não pode substituir o áudio salvo durante a fase.
	if (
		current_scene == null
		or current_scene.scene_file_path == MAIN_MENU_SCENE
	):
		return false

	var current_player := get_tree().get_first_node_in_group(
		"player"
	) as Player

	if current_player == null:
		return false

	if not current_scene.is_ancestor_of(current_player):
		return false

	if not current_player.checkpoint_enabled:
		return false

	# Fechar a janela na tela de morte não pode substituir o último checkpoint
	# válido por um estado em que o jogador já está morto.
	if current_player.get_vida() <= 0.0:
		return false

	create_checkpoint(current_player, audio_state_override)
	return true


func clear_save() -> void:
	save_data.clear()
	checkpoint_world_state.clear()
	state_player.clear()
	checkpoint_progress.clear()
	checkpoint_audio_state.clear()

	checkpoint_scene_path = ""
	checkpoint_player_scene_path = ""
	checkpoint_pos = INVALID_CHECKPOINT_POS
	restore_checkpoint_pending = false
	restore_audio_pending = false
	MusicController.stop_all_audio()

	tempo_restante = -1.0
	tempo_atual = -1.0

	scene_manager.player = null
	scene_manager.last_scene_name = ""

	if FileAccess.file_exists(FILE_PATH):
		var absolute_path: String = ProjectSettings.globalize_path(
			FILE_PATH
		)

		DirAccess.remove_absolute(absolute_path)

	Configs.configs["job"] = ""
	Configs.configs["character"] = ""
	Configs.configs["difficulty"] = ""

	SaveLoad.save_data = Configs.configs.duplicate(true)
	SaveLoad._save()


func reset_progress() -> void:
	clear_save()

	get_tree().paused = false
	get_tree().change_scene_to_file(
		CHARACTER_SELECTION_SCENE
	)


func _notification(what: int) -> void:
	if (
		what == NOTIFICATION_WM_CLOSE_REQUEST
		or what == NOTIFICATION_APPLICATION_PAUSED
	):
		save_current_session()


# O estado global participa do mesmo snapshot/rollback do restante do mundo.
# Migração usa a fala concluída, nunca apenas o início da evacuação.
func office_mission_state(current_player: Player = null) -> Dictionary:
	var estado: Variant = load_global_state("hall_quest_01")
	if estado is Dictionary:
		return estado
	var hall: Dictionary = save_data.get("res://Scenes/andar_hall.tscn", {}).get("hall_quest_01", {})
	var liberado := bool(hall.get("elevator_third_floor_unlocked", false))
	if current_player != null:
		liberado = liberado or current_player.balao_de_pensamento.foi_concluido("hall:hall_quest_01:pos_saida_2")
	estado = {
		"elevator_third_floor_unlocked": liberado,
		"arrived_third_floor": bool(hall.get("arrived_third_floor", false)),
		"indicator_remaining": 0.0
	}
	save_global_state("hall_quest_01", estado)
	return estado
