extends Node
## Estado pequeno e independente. As fases ficam abertas para testar no editor.
var concluidas: Array = [[false, false, false, false], [false, false, false, false], [false]]
var som_ativo: bool = true
var modo_teste: bool = false
const ARQUIVO := "user://asimov_progresso.cfg"
const CAMINHOS := [
	["res://Minigames/Minigame1/levels/UnlockSecurity.tscn", "res://Minigames/Minigame1/levels/unlock_security_2.tscn", "res://Minigames/Minigame1/levels/unlock_security_3.tscn", "res://Minigames/Minigame1/levels/unlock_security_4.tscn"],
	["res://MinigamesProgramador/Minigame2/levels/slider_hacking.tscn", "res://MinigamesProgramador/Minigame2/levels/slider_hacking_2.tscn", "res://MinigamesProgramador/Minigame2/levels/slider_hacking_3.tscn", "res://MinigamesProgramador/Minigame2/levels/slider_hacking_4.tscn"],
	["res://MinigamesProgramador/Minigame3/recovery_system.tscn"]
]

func _ready() -> void:
	modo_teste = OS.get_cmdline_user_args().has("--test")
	if modo_teste:
		return
	var arquivo := ConfigFile.new()
	if arquivo.load(ARQUIVO) == OK:
		for jogo in range(3):
			for fase in range(concluidas[jogo].size()):
				concluidas[jogo][fase] = bool(arquivo.get_value("fases", "%d_%d" % [jogo, fase], false))
		som_ativo = bool(arquivo.get_value("opcoes", "som", true))

func salvar() -> void:
	if modo_teste:
		return
	var arquivo := ConfigFile.new()
	for jogo in range(3):
		for fase in range(concluidas[jogo].size()):
			arquivo.set_value("fases", "%d_%d" % [jogo, fase], concluidas[jogo][fase])
	arquivo.set_value("opcoes", "som", som_ativo)
	arquivo.save(ARQUIVO)

func concluir(jogo: int, fase: int) -> void:
	concluidas[jogo][fase] = true
	salvar()

func abrir(jogo: int, fase: int) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(CAMINHOS[jogo][fase])

func menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Interface/menu.tscn")
