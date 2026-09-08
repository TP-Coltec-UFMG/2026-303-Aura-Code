extends Control

signal tempo_esgotado

const TEMPO_LIMITE_DE_JOGO: float = 60 * 10
const TEMPO_INICIO_AUDIO: float = 11.0
const TEMPO_INICIO_COUNT_DOWN: float = 46.0

@onready var audio_stream_player_2d: AudioStreamPlayer2D = $AudioStreamPlayer2D
@onready var label: Label = $Label

var tempo_decorrido: float = 0.0
var ultimo_segundo_exibido: int = -1
var finalizado: bool = false
var audio_iniciado: bool = false
var count_down_audio_iniciado: bool = false


func _ready() -> void:
	add_to_group("temporizador_jogo")
	if SaveGame.tempo_atual >= 0.0:
		carregar_tempo_restante(SaveGame.tempo_atual)
	else:
		SaveGame.tempo_atual = get_tempo_restante()
		atualizar_label()
		set_process(true)


func _process(delta: float) -> void:
	tempo_decorrido = minf(
		tempo_decorrido + delta,
		TEMPO_LIMITE_DE_JOGO
	)

	var tempo_restante_atual: float = get_tempo_restante()

	SaveGame.tempo_atual = tempo_restante_atual

	var segundos_restantes := maxi(
		0,
		ceili(tempo_restante_atual)
	)
	
	if segundos_restantes <= TEMPO_INICIO_COUNT_DOWN and not count_down_audio_iniciado:
		count_down_audio_iniciado = true
		MusicController._start_countdown()
		

	if segundos_restantes <= TEMPO_INICIO_AUDIO and not audio_iniciado:
		audio_iniciado = true
		audio_stream_player_2d.play()

	if segundos_restantes != ultimo_segundo_exibido:
		ultimo_segundo_exibido = segundos_restantes
		atualizar_label()
		

	if tempo_decorrido >= TEMPO_LIMITE_DE_JOGO:
		fim_de_jogo()


func get_tempo_restante() -> float:
	return maxf(
		0.0,
		TEMPO_LIMITE_DE_JOGO - tempo_decorrido
	)


func carregar_tempo_restante(novo_tempo: float) -> void:
	var tempo_carregado := clampf(
		novo_tempo,
		0.0,
		TEMPO_LIMITE_DE_JOGO
	)

	tempo_decorrido = TEMPO_LIMITE_DE_JOGO - tempo_carregado
	ultimo_segundo_exibido = -1
	audio_iniciado = tempo_carregado <= TEMPO_INICIO_AUDIO
	count_down_audio_iniciado = (
		tempo_carregado <= TEMPO_INICIO_COUNT_DOWN
	)

	SaveGame.tempo_atual = tempo_carregado

	audio_stream_player_2d.stop()
	audio_stream_player_2d.stream_paused = false

	atualizar_label()

	# Se o tempo carregado for 0 ou menor, encerra o jogo imediatamente
	if tempo_carregado <= 0.0:
		fim_de_jogo()
		return

	finalizado = false

	if count_down_audio_iniciado:
		MusicController._start_countdown(
			maxf(
				0.0,
				TEMPO_INICIO_COUNT_DOWN - tempo_carregado
			)
		)
	else:
		MusicController._stop_countdown()

	if audio_iniciado:
		var posicao_audio := maxf(
			0.0,
			TEMPO_INICIO_AUDIO - tempo_carregado
		)

		audio_stream_player_2d.play(posicao_audio)

	set_process(true)


func pausar_timer() -> void:
	SaveGame.tempo_atual = get_tempo_restante()

	set_process(false)
	audio_stream_player_2d.stream_paused = true


func comecar_timer() -> void:
	if finalizado:
		return

	set_process(true)
	audio_stream_player_2d.stream_paused = false


func reiniciar_timer() -> void:
	tempo_decorrido = 0.0
	ultimo_segundo_exibido = -1
	finalizado = false
	audio_iniciado = false
	count_down_audio_iniciado = false

	SaveGame.tempo_atual = TEMPO_LIMITE_DE_JOGO

	audio_stream_player_2d.stop()
	audio_stream_player_2d.stream_paused = false
	MusicController._stop_countdown()

	atualizar_label()
	set_process(true)


func atualizar_label() -> void:
	var tempo_restante := maxi(
		0,
		ceili(get_tempo_restante())
	)

	@warning_ignore("integer_division")
	var minutos := tempo_restante / 60
	var segundos := tempo_restante % 60

	label.text = "%02dm : %02ds" % [minutos, segundos]


func fim_de_jogo() -> void:
	if finalizado:
		return

	finalizado = true
	SaveGame.tempo_atual = 0.0

	set_process(false)

	label.text = "00m : 00s"
	tempo_esgotado.emit()


func _on_tempo_esgotado() -> void:
	MusicController._stop_som_alarme()
	$Timer.start()
	await $Timer.timeout
	get_tree().change_scene_to_file("res://Cutscenes/cutscene_final_1.tscn")


func _on_man_player_jogador_morreu() -> void:
	hide()
	pausar_timer()
